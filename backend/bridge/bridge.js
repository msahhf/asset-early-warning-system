/**
 * ASSET 2.1 PC Seri Port Köprü Servisi (Bridge Service)
 *
 * Görevi:
 * 1. USB üzerinden bağlı olan ASSET 2.1 Hub (Merkezi Deneyap Kart) seri portunu dinler.
 * 2. Gelen binary veya JSON paketleri (AssetPacket - 13 bayt veya JSON) yakalar.
 * 3. CRC-8 bütünlük kontrolünü yapar.
 * 4. Çözümlenen telemetriyi yerel Backend Ingest API'sine (/api/sensors/ingest) iletir.
 * 5. Backend'den eşik senkronizasyonu: Bağlantı kurulduğunda VE config:updated event'i
 *    geldiğinde firmware'e THRESHOLD:<val>\n komutunu seri porta yazar.
 *
 * Çalıştırma:
 * node bridge.js --port=/dev/ttyUSB0 --baud=115200
 * node bridge.js --mock (Donanım takılı değilken sanal seri port akışı simüle eder)
 */

const path = require("path");
require("dotenv").config({ path: path.join(__dirname, "..", ".env") });
const http = require("http");

if (!process.env.INGEST_API_KEY) {
  console.error("INGEST_API_KEY tanımlı değil, .env dosyasını kontrol edin.");
  process.exit(1);
}

const BACKEND_HOST = process.env.BACKEND_HOST || "localhost";
const BACKEND_PORT = process.env.BACKEND_PORT || 5000;
const INGEST_PATH = "/api/sensors/ingest";
const THRESHOLDS_PATH = "/api/config/thresholds";
const INGEST_API_KEY = process.env.INGEST_API_KEY;
const ADMIN_API_KEY = process.env.ADMIN_API_KEY || "";

if (!ADMIN_API_KEY) {
  console.warn("UYARI: ADMIN_API_KEY tanımlı değil; eşik senkronizasyonu (GET /api/config/thresholds) 503 alabilir.");
}

// ── Çoklu Port ve Otomatik Algılama Yapılandırması ──
const rawPortArg = process.argv.find((arg) => arg.startsWith("--port=") || arg.startsWith("--ports="))?.split("=")[1];
const baudRate = parseInt(process.argv.find((arg) => arg.startsWith("--baud="))?.split("=")[1] || "115200");
const isMock = process.argv.includes("--mock");

// ── CRC-8 Dallas/Maxim Hesaplayıcı ──
function calculateCrc8(buffer) {
  let crc = 0x00;
  for (let i = 0; i < buffer.length; i++) {
    crc ^= buffer[i];
    for (let j = 0; j < 8; j++) {
      if (crc & 0x80) {
        crc = ((crc << 1) ^ 0x07) & 0xff;
      } else {
        crc = (crc << 1) & 0xff;
      }
    }
  }
  return crc;
}

// ── 13 Baytlık AssetPacket Binary Ayrıştırıcı ──
function parseAssetPacket(buf) {
  if (buf.length < 13) {
    throw new Error(`Eksik paket uzunluğu: ${buf.length} bayt (13 bayt bekleniyor)`);
  }

  const payload = buf.subarray(0, 12);
  const receivedCrc = buf[12];
  const computedCrc = calculateCrc8(payload);

  if (receivedCrc !== computedCrc) {
    console.warn(`⚠️ CRC Uyuşmazlığı: Gelen=0x${receivedCrc.toString(16)}, Hesaplanan=0x${computedCrc.toString(16)}`);
  }

  const schemaVersion = buf.readUInt8(0);
  const deviceId = buf.readUInt8(1);
  const tempCx10 = buf.readUInt16LE(2);
  const tempC = parseFloat((tempCx10 / 10.0).toFixed(1));
  const humidityPct = buf.readUInt8(4);
  const smokeRaw = buf.readUInt16LE(5);
  const seqNo = buf.readUInt32LE(7);
  const batteryPct = buf.readUInt8(11);

  return {
    schemaVersion,
    deviceId: String(deviceId),
    tempC,
    humidityPct,
    smokeRaw,
    seqNo,
    batteryPct,
    crcOk: receivedCrc === computedCrc,
  };
}

// ── Paket Tekilleştirme (Deduplication) ──
const lastSeenSeq = {};

// ── Backend'e Forward Etme ──
function forwardToBackend(packet, portName = "Bilinmeyen") {
  // CRC hatası olan BINARY paketler backend'e asla iletilmez: bozuk ölçüm
  // füzyon/SensorLog'a "gerçek okuma" olarak girmesin. crcOk alanı yalnızca
  // binary (26-hex / mock) yolunda üretilir; JSON ve metin-fallback
  // yollarında undefined'dır, bu kontrol onları etkilemez (=== false).
  if (packet && packet.crcOk === false) {
    console.error(
      `🚫 [CRC Reddi] Node #${packet.deviceId} (${portName}): CRC-8 uyuşmazlığı, paket backend'e gönderilmedi (Seq=${packet.seqNo}).`
    );
    return;
  }
  // BLE reklamları ve çoklu portlar saniyede birçok kez tekrarlanır. Aynı seqNo tekrarını süz:
  if (packet.deviceId && packet.seqNo !== undefined) {
    if (lastSeenSeq[packet.deviceId] === packet.seqNo) {
      return;
    }
    lastSeenSeq[packet.deviceId] = packet.seqNo;
  }

  const postData = JSON.stringify(packet);

  const req = http.request(
    {
      hostname: BACKEND_HOST,
      port: BACKEND_PORT,
      path: INGEST_PATH,
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Content-Length": Buffer.byteLength(postData),
        "x-api-key": INGEST_API_KEY,
      },
    },
    (res) => {
      let body = "";
      res.on("data", (chunk) => (body += chunk));
      res.on("end", () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          console.log(`✅ [İletildi] Node #${packet.deviceId} (${portName}): Duman=${packet.smokeRaw}, Isı=${packet.tempC}°C, Seq=${packet.seqNo}, Kaynak=${packet.source || "hardware"}`);
        } else {
          console.error(`❌ [Backend Hatası ${res.statusCode}]:`, body);
        }
      });
    }
  );

  req.on("error", (err) => {
    console.error(`❌ [İletim Hatası]: Backend'e ulaşılamadı (${err.message})`);
  });

  req.write(postData);
  req.end();
}

// ── Aktif Seri Portlar Listesi (Eşik yayını için) ──
const openSerialPorts = [];

// ── Eşik Senkronizasyonu: Backend'den mevcut smokeThreshold'u çek ──
function fetchAndSendThreshold() {
  const req = http.request(
    {
      hostname: BACKEND_HOST,
      port: BACKEND_PORT,
      path: THRESHOLDS_PATH,
      method: "GET",
      headers: {
        "x-admin-key": ADMIN_API_KEY,
      },
    },
    (res) => {
      let body = "";
      res.on("data", (chunk) => (body += chunk));
      res.on("end", () => {
        try {
          const data = JSON.parse(body);
          const threshold = data?.data?.smokeThreshold;
          if (threshold !== undefined) {
            broadcastThreshold(threshold);
          } else {
            console.warn("⚠️ [Eşik Sync] smokeThreshold alınamadı:", body);
          }
        } catch (e) {
          console.error("❌ [Eşik Sync] JSON parse hatası:", e.message);
        }
      });
    }
  );
  req.on("error", (err) => {
    console.warn(`⚠️ [Eşik Sync] Backend'e bağlanılamadı: ${err.message} — Firmware yerel eşik değerini kullanmaya devam edecek.`);
  });
  req.end();
}

/**
 * Açık olan tüm seri portlara THRESHOLD:<val>\n komutu yazar.
 * @param {number} value
 */
function broadcastThreshold(value) {
  const cmd = `THRESHOLD:${value}\n`;
  if (isMock) {
    console.log(`[Eşik Sync][MOCK] Firmware'e gönderilecek komut: ${cmd.trim()}`);
    return;
  }
  if (openSerialPorts.length === 0) {
    console.warn("⚠️ [Eşik Sync] Açık seri port bulunamadı.");
    return;
  }
  openSerialPorts.forEach(({ path, port }) => {
    if (port && port.isOpen) {
      port.write(cmd, (err) => {
        if (err) {
          console.error(`❌ [Eşik Sync] (${path}) Yazma hatası: ${err.message}`);
        } else {
          console.log(`🔧 [Eşik Sync] (${path}) Gönderildi: ${cmd.trim()} (backend smokeThreshold: ${value})`);
        }
      });
    }
  });
}

// ── Socket.io bağlantısı: config:updated event'ini dinle ──
function connectSocketForThresholdSync() {
  try {
    if (!ADMIN_API_KEY) {
      // Socket tarafı anahtar gerektirir: anahtarsız bağlantı sunucuda public
      // odaya alınır ve config:updated ASLA ulaşmaz. Sessiz public düşüş yerine
      // socket kurulmaz; başlangıç eşik çekimi HTTP üzerinden denenir (alert
      // durumunda kullanıcıya görünen uyarı yukarıda verilmiştir).
      console.warn("⚠️ [Eşik Sync] ADMIN_API_KEY tanımlı değil; canlı eşik senkronizasyonu (config:updated) devre dışı. HTTP ile başlangıç çekimi deneniyor...");
      setTimeout(() => fetchAndSendThreshold(), 2000);
      return;
    }

    const { io: ioClient } = require("socket.io-client");
    const backendUrl = `http://${BACKEND_HOST}:${BACKEND_PORT}`;
    // Handshake kimlik doğrulama: eşik senkronu için dinlediği config:updated
    // korumalı olaydır; anahtar auth payload'ında taşınır (URL/query değil,
    // log'a yazılmaz). Yanlış anahtar sunucuda bağlantıyı reddeder.
    const socket = ioClient(backendUrl, {
      reconnection: true,
      reconnectionDelay: 3000,
      auth: { key: ADMIN_API_KEY },
    });

    socket.on("connect", () => {
      console.log(`🔗 [Socket] Backend'e bağlandı (${backendUrl}) — config:updated izleniyor.`);
      console.log("🔄 [Eşik Sync] Bağlantı kuruldu, mevcut eşik değeri çekiliyor...");
      fetchAndSendThreshold();
    });

    socket.on("config:updated", (newConfig) => {
      const threshold = newConfig?.smokeThreshold;
      if (threshold !== undefined) {
        console.log(`📡 [config:updated] Yeni smokeThreshold: ${threshold} — Firmware'e iletiliyor...`);
        broadcastThreshold(threshold);
      }
    });

    socket.on("disconnect", () => {
      console.warn("🔌 [Socket] Backend bağlantısı kesildi, yeniden bağlanılıyor...");
    });

    socket.on("connect_error", (err) => {
      console.warn(`⚠️ [Socket] Bağlantı hatası: ${err.message}`);
    });
  } catch (e) {
    if (e.code === "MODULE_NOT_FOUND") {
      console.warn("⚠️ [Eşik Sync] socket.io-client bulunamadı. HTTP ile başlangıç senkronizasyonu deneniyor...");
      setTimeout(() => fetchAndSendThreshold(), 2000);
    } else {
      console.error("❌ [Socket] Beklenmeyen hata:", e.message);
    }
  }
}

// ── Mock veya Gerçek Port Başlatma ──
if (isMock) {
  console.log("==================================================");
  console.log("🛰️ ASSET 2.1 PC Seri Port Köprü Servisi (Bridge)");
  console.log(`📡 Hedef Backend: http://${BACKEND_HOST}:${BACKEND_PORT}`);
  console.log("🔌 Çalışma Modu: MOCK (Sanal Akış)");
  console.log("==================================================");
  console.log("ℹ️ Donanım bağlı değil. 5 saniyede bir simüle paketler üretilip gönderilecek...");

  connectSocketForThresholdSync();

  let seq = 1;
  setInterval(() => {
    for (let id = 1; id <= 5; id++) {
      seq++;
      const buf = Buffer.alloc(13);
      buf.writeUInt8(0x01, 0); // schema version
      buf.writeUInt8(id, 1);   // device_id
      buf.writeUInt16LE(Math.round((24.0 + Math.random()) * 10), 2); // temp_c_x10
      buf.writeUInt8(Math.round(50 + Math.random() * 5), 4); // humidity_pct
      buf.writeUInt16LE(Math.round(250 + Math.random() * 50), 5); // smoke_raw
      buf.writeUInt32LE(seq, 7); // seq_no
      buf.writeUInt8(95, 11); // battery_pct
      const crc = calculateCrc8(buf.subarray(0, 12));
      buf.writeUInt8(crc, 12); // crc8

      try {
        const parsed = parseAssetPacket(buf);
        parsed.source = "mock";
        forwardToBackend(parsed, "MOCK");
      } catch (err) {
        console.error("Paket parse hatası:", err);
      }
    }
  }, 5000);
} else {
  // Gerçek Donanım Seri Port Yönetimi
  (async () => {
    try {
      const { SerialPort } = require("serialport");
      const { ReadlineParser } = require("@serialport/parser-readline");

      let portPaths = [];

      if (rawPortArg) {
        // Kullanıcı virgülle veya tek port vermişse: --port=/dev/ttyUSB0,/dev/ttyUSB1
        portPaths = rawPortArg.split(",").map((p) => p.trim()).filter(Boolean);
      } else {
        // Port belirtilmemişse bağlı tüm USB/ACM portlarını otomatik tespit et
        console.log("🔍 Seri portlar taranıyor (Auto-detect)...");
        const availablePorts = await SerialPort.list();
        const usbPorts = availablePorts.filter(
          (p) =>
            p.path.includes("ttyUSB") ||
            p.path.includes("ttyACM") ||
            (p.vendorId && p.vendorId.toLowerCase() === "10c4") // CP210x
        );
        portPaths = usbPorts.map((p) => p.path);
        if (portPaths.length === 0) {
          portPaths = ["/dev/ttyUSB0"]; // Fallback
        }
      }

      console.log("==================================================");
      console.log("🛰️ ASSET 2.1 PC Seri Port Köprü Servisi (Bridge)");
      console.log(`📡 Hedef Backend: http://${BACKEND_HOST}:${BACKEND_PORT}`);
      console.log(`🔌 Dinlenecek Port(lar): ${portPaths.join(", ")} (@ ${baudRate} baud)`);
      console.log("==================================================");

      connectSocketForThresholdSync();

      portPaths.forEach((path) => {
        try {
          const port = new SerialPort({ path, baudRate });
          const parser = port.pipe(new ReadlineParser({ delimiter: "\n" }));

          // Port için son görülen Node ID hafızası (metin satırları için)
          let lastDetectedNodeId = null;

          port.on("open", () => {
            console.log(`✅ Seri port açıldı: ${path} (${baudRate} baud)`);
            openSerialPorts.push({ path, port });
            // Portlar açıldıktan sonra backend eşiğini senkronize et (debounce)
            if (global.thresholdSyncTimeout) clearTimeout(global.thresholdSyncTimeout);
            global.thresholdSyncTimeout = setTimeout(() => fetchAndSendThreshold(), 800);
          });

          parser.on("data", (line) => {
            const trimmed = line.trim();
            if (!trimmed) return;

            // Firmware onay mesajlarını filtrele
            if (trimmed.startsWith("THRESHOLD_ACK:") || trimmed.startsWith("[CONFIG]")) {
              console.log(`📟 [Firmware][${path}]: ${trimmed}`);
              return;
            }

            // Başlatma mesajından Node ID yakala (örn: 🌲 ASSET 2.0 Node #2 Başlatılıyor...)
            const initMatch = trimmed.match(/Node\s*#(\d+)/i);
            if (initMatch) {
              lastDetectedNodeId = initMatch[1];
            }

            console.log(`📥 [${path}]: ${trimmed}`);

            // 1. JSON formatında gelmişse (Hub veya Node JSON çıktısı)
            if (trimmed.startsWith("{") && trimmed.endsWith("}")) {
              try {
                const json = JSON.parse(trimmed);
                if (!json.source) json.source = "hardware";
                if (json.deviceId) {
                  lastDetectedNodeId = String(json.deviceId);
                }
                forwardToBackend(json, path);
              } catch (e) {
                console.error(`❌ [${path}] JSON parse hatası:`, e.message);
              }
            }
            // 2. 26 karakter Hex string gelmişse (Binary AssetPacket)
            else if (/^[0-9a-fA-F]{26}$/.test(trimmed)) {
              try {
                const buf = Buffer.from(trimmed, "hex");
                const packet = parseAssetPacket(buf);
                packet.source = "hardware";
                if (packet.deviceId) {
                  lastDetectedNodeId = String(packet.deviceId);
                }
                forwardToBackend(packet, path);
              } catch (e) {
                console.error(`❌ [${path}] HEX parse hatası:`, e.message);
              }
            }
            // 3. Node metin formatında gelmişse ([Seq #1] A0 Ham: ... | Telafili Duman: ... | Sıcaklık: ... | Nem: ...)
            // Firmware arkasından hemen JSON da basıyor; JSON gelmediği durumlar için akıllı fallback:
            else if (trimmed.includes("[Seq #")) {
              try {
                const seqMatch = trimmed.match(/\[Seq #(\d+)\]/);
                const dumanMatch = trimmed.match(/Telafili Duman:\s*(\d+)/);
                const tempMatch = trimmed.match(/Sıcaklık:\s*([\d\.]+)°C/);
                const nemMatch = trimmed.match(/Nem:\s*([\d\.]+)%/);

                // Eğer bu porttan daha önce bir JSON geldiyse veya tespit edilmişse onun Node ID'sini kullan
                if (dumanMatch && tempMatch && nemMatch && lastDetectedNodeId) {
                  const packet = {
                    deviceId: String(lastDetectedNodeId),
                    seqNo: seqMatch ? parseInt(seqMatch[1]) : 1,
                    smokeRaw: parseInt(dumanMatch[1]),
                    tempC: parseFloat(tempMatch[1]),
                    humidityPct: parseFloat(nemMatch[1]),
                    batteryPct: 95,
                    source: "hardware",
                  };
                  forwardToBackend(packet, path);
                }
              } catch (e) {
                console.error(`❌ [${path}] Metin parse hatası:`, e.message);
              }
            }
          });

          port.on("error", (err) => {
            console.error(`❌ Seri port hatası (${path}): ${err.message}`);
          });

          port.on("close", () => {
            console.warn(`🔌 Seri port kapandı: ${path}`);
            const idx = openSerialPorts.findIndex((p) => p.path === path);
            if (idx !== -1) openSerialPorts.splice(idx, 1);
          });
        } catch (err) {
          console.error(`❌ Port açılırken hata (${path}):`, err.message);
        }
      });
    } catch (e) {
      console.warn(`⚠️ Seri port başlatılamadı: ${e.message}`);
      if (e.code === "MODULE_NOT_FOUND") {
        console.log("👉 Çözüm: Backend dizininde 'npm install serialport @serialport/parser-readline' komutunu çalıştırın.");
      }
      console.log("ℹ️ Donanım olmadan test etmek için: node bridge/bridge.js --mock");
    }
  })();
}
