#!/usr/bin/env bash
# ==============================================================================
# ASSET 2.1 - Backend + Bridge tek komut kontrol scripti
#
# Calistirma yeri: repo koku (assetaydem). Yapi:
#   backend/ (server.js + src/ + public/ + bridge/) | iot/ (firmware)
#   docs/ | 3d_files/
# Kullanim:
#   ./asset-control.sh start [--mock | --port=/dev/ttyUSB0]
#   ./asset-control.sh stop
#   ./asset-control.sh status
#
# Davranis:
#   start: backend'i tek kez baslatir (node server.js - npm run dev ile ayni
#          uygulama; nodemon izleyicisi yok ki surec sahipligi deterministik
#          kalsin). Saglik cagesi: GET /api/health (200 beklenir).
#          Hub tespiti bridge kodundaki kuralin birebir aynidir
#          (bridge.js ~321-327, Auto-detect; OR kurallari):
#          path ttyUSB | path ttyACM | vendorId 10c4 (CP210x). Sonra:
#             hub yok              -> bridge --mock
#             tam 1 hub adayi      -> bridge --port=<yol> (canli)
#             birden cok adaylik   -> rastgele secim YOK; belirsizlik bildirilir
#                                     (kullanici --port= ile acikca secer)
#             hub acilamadi        -> mock'a sessiz gecis YOK; sebep bildirilir
#   stop : YALNIZCA bu scriptin pid dosyalarina kaydettigi (setsid ile kendi
#          surec grubunu kurmus) surecleri durdurur. pgrep/pkill yok; kayit
#          + pgid dogrulamasi + cmdline eslesmesi olmadan hicbir surece
#          dokunulmaz. Sistemde onceden calisan kullanici/systemd surecleri
#          etkilenmez.
#   status: kayitli sureclerin canliligi + bridge modu + backend sagligi.
#
# NOT: ADMIN_API_KEY / INGEST_API_KEY bu scriptte sabitlenmez ve yazdirilmaz;
#      backend/bridge kendi .env yukleme davranisini kullanir. Yalniz yerel
#      gelistirma MongoDB kurali (AGENTS.md) surec env'ine gecilir:
#      MONGODB_URI=mongodb://127.0.0.1:27017/asset_db
# ==============================================================================

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$ROOT/backend"
SERVER_JS="$BACKEND_DIR/server.js"
BRIDGE_JS="$BACKEND_DIR/bridge/bridge.js"

STATE_DIR="${ASSET_CONTROL_STATE:-/tmp/opencode/asset-control}"
BE_PID_FILE="$STATE_DIR/backend.pid"
BR_PID_FILE="$STATE_DIR/bridge.pid"
BR_MODE_FILE="$STATE_DIR/bridge.mode"
BE_LOG="$STATE_DIR/backend.log"
BR_LOG="$STATE_DIR/bridge.log"

SERVER_PORT="${ASSET_PORT:-5000}"
MONGO_URI="mongodb://127.0.0.1:27017/asset_db"

BACKEND_READY_TIMEOUT=30   # sn: MongoDB 5s + rehydrate ~4s + pay
LIVE_OPEN_TIMEOUT=12       # sn: "Seri port acildi" log onayi icin
STOP_GRACE=7               # sn: SIGTERM sonru SIGKILL

say()  { printf '%s\n' "$*"; }
fail() { printf '%s\n' "HATA: $*" >&2; exit "${2:-1}"; }
note() { printf '%s\n' "UYARI: $*" >&2; }

for t in bash curl node setsid flock grep awk sed tail; do
  command -v "$t" >/dev/null 2>&1 || fail "Gerekli ara bulunamadi: $t" 127
done

[ -f "$SERVER_JS" ] || fail "Backend bulunamadi: $SERVER_JS (script proje kokunden calistirilmali)"
[ -f "$BRIDGE_JS" ] || fail "Bridge bulunamadi: $BRIDGE_JS"

mkdir -p "$STATE_DIR" 2>/dev/null || fail "State dizini kurulamadi: $STATE_DIR"

# --- kilit: ayni anda cift start/stop carismasin ------------------------------
# Dikkat: exec satirinda 2>/dev/null KULLANILMAZ - exec'in yonlendirmesi tum
# scriptin stderr'ini kalici olarak degistirir ve hata mesajlarini yutardi.
acquire_lock() {
  [ -w "$STATE_DIR" ] || fail "State dizinine yazma izni yok: $STATE_DIR" 1
  exec 9>"$STATE_DIR/.lock"   # acilamazsa bash otomatik hata verir ve cikar
  flock -n 9 || fail "Baska bir asset-control start/stop hala calisiyor (kilit mesgul). Bekleyip tekrar deneyin." 1
}

# --- surec yardimcilari (pgrep/pkill YOK) -------------------------------------
read_pid() {
  local p
  p="$(head -n1 "$1" 2>/dev/null | tr -cd '0-9')"
  printf '%s' "$p"
}

# proc_stat_field <pid> <alan-idx (') halinden sonra)>: pgrp = alan 3
stat_pgrp() {
  local pid="$1" f
  f="$(cat "/proc/$pid/stat" 2>/dev/null)" || { printf ''; return; }
  # comm alanindaki parantez/space tuzagina karsi: son ')' sonrasi: state ppid pgrp
  printf '%s\n' "$f" | sed 's/^.*) //' | awk '{print $3}'
}

# proc_valid <pid> <cmdline-icermeli> -> 0: canli + uyumlu + grup lideri
proc_valid() {
  local pid="$1" must="$2" cmd pgid
  [ -n "$pid" ] || return 1
  [ -d "/proc/$pid" ] || return 1
  [ -r "/proc/$pid/cmdline" ] || { kill -0 "$pid" 2>/dev/null || return 2; return 3; }
  cmd="$(tr '\0' ' ' <"/proc/$pid/cmdline")"
  case "$cmd" in *"$must"*) true ;; *) return 2 ;; esac
  pgid="$(stat_pgrp "$pid")"
  [ -n "$pgid" ] && [ "$pgid" = "$pid" ] || return 3
  return 0
}

# port_busy: 127.0.0.1:PORT'e cabuk TCP baglanti denemesi (herhangi servise)
port_busy() {
  timeout 3 bash -c "exec 3<>/dev/tcp/127.0.0.1/$SERVER_PORT" >/dev/null 2>&1
}

backend_health_code() {
  curl -s -o /dev/null -m 3 -w '%{http_code}' "http://127.0.0.1:$SERVER_PORT/api/health" 2>/dev/null
}

backend_alive() {
  local pid; pid="$(read_pid "$BE_PID_FILE")"
  [ -n "$pid" ] && proc_valid "$pid" "server.js"
}

bridge_alive() {
  local pid; pid="$(read_pid "$BR_PID_FILE")"
  [ -n "$pid" ] && proc_valid "$pid" "bridge/bridge.js"
}

bridge_cmdline() {
  local pid; pid="$(read_pid "$BR_PID_FILE")"
  tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null
}

bridge_mode_from_cmdline() {
  local cmd="$1" p
  case "$cmd" in *--mock*) printf 'mock'; return ;; esac
  p="$(printf '%s' "$cmd" | grep -o -- '--port=[^ ]*' | head -n1 | cut -d= -f2-)"
  if [ -n "$p" ]; then printf 'live:%s' "$p"; else printf 'unknown'; fi
}

# stop_group <etiket> <pid_dosyasi> <cmdline-eslesme>
#   Yalniz kayitli pid + pgid==pid + cmdline eslesmesi saglanirsa surec GRUBunu
#   (setsid ile kendi grubumuzu) durdurur. Diger hicbir surece dokunmaz.
stop_group() {
  local label="$1" pidfile="$2" must="$3"
  local pid pgid waited=0 rc=1
  pid="$(read_pid "$pidfile")"
  if [ -z "$pid" ]; then
    say "MID: $label - kayit yok (pid dosyasi bos/yok)."
    return 0
  fi
  if ! proc_valid "$pid" "$must"; then
    say "BRK: $label - kayitli pid $pid canli degil/bayat (dokunulmadi; pid dosyasi yenileniyor)."
    : > "$pidfile"
    return 0
  fi
  pgid="$(stat_pgrp "$pid")"
  if [ "$pgid" != "$pid" ]; then
    # pid re-use riski: eskiden bizim grup lideri degil. DURDURMA - dokunulmaz!
    note "$label - pid $pid artik beklenmadik grup lideri degil (pgid=$pgid). Durdurulmadi; manuel kontrol edin."
    : > "$pidfile"
    return 1
  fi
  say "STP: $label durduruluyor (pid $pid, grup $pgid, SIGTERM)..."
  kill -TERM -- "-$pgid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null
  while [ "$waited" -lt $((STOP_GRACE * 10)) ]; do
    if ! [ -e "/proc/$pid" ]; then rc=0; break; fi
    sleep 0.1
    waited=$((waited + 1))
    if [ "$waited" -ge $((STOP_GRACE * 10)) ]; then break; fi
  done
  if [ "$rc" -ne 0 ] && [ -e "/proc/$pid" ]; then
    say "WRN: $label - SIGTERM yetmedi (grup $pgid), SIGKILL..."
    kill -KILL -- "-$pgid" 2>/dev/null || kill -KILL "$pid" 2>/dev/null
    sleep 0.3
    if [ -e "/proc/$pid" ]; then
      note "$label - SIGKILL sonrasi hala canli: manuel mudahale gerekebilir ($pid)."
      return 1
    fi
  fi
  : > "$pidfile"
  say "OKK: $label durduruldu."
  return 0
}

# launch_bg <log_dosyasi> <calisma_dizini> <pid_dosyasi> <komut...>
#   Sureci setsid ile kendi grubunda, log dosyasina ciktilarla baslatir; pid'i
#   pid dosyasina yazar (pid sadece dosyadan okunur - capture yok). fd9 (flock)
#   cocuk sureclere kapatilir (kilit devralinmasin). rc=0 baslangic, rc=1 hata.
#   Dikkat: cagrilara setsid GECMEZ (tek setsid; cift setsid fork yaratip pid
#   karisma yaratir). Cocuk surec: envek/arg forma serbest.
launch_bg() {
  local logfile="$1" workdir="$2" pidfile="$3"; shift 3
  local pid pgid tries=0
  ( cd "$workdir" && exec setsid "$@" ) 9>&- >"$logfile" 2>&1 &
  pid="$!"
  # Yaris payiani: bg altkabuk bir kac ms icinde setsid'e exec olur ve pgid==pid
  # olur. Hemen tek okuma yetmez - 2 sn'ye kadar koşula-agir (retry) bakilir.
  pgid=""
  while [ "$tries" -lt 20 ]; do
    pgid="$(ps -o pgid= -p "$pid" 2>/dev/null | tr -d ' ')"
    [ -n "$pgid" ] && [ "$pgid" = "$pid" ] && break
    if ! [ -e "/proc/$pid" ]; then
      printf '%s\n' "Ic hata: baslatilan surec ortadan kayboldu (pid $pid)." >&2
      return 1
    fi
    sleep 0.1
    tries=$((tries + 1))
  done
  if [ "$pgid" != "$pid" ]; then
    printf '%s\n' "Ic hata: surec grup lideri olmadan basladi ($pid, pgid=$pgid). Durduruluyor..." >&2
    kill -TERM "$pid" 2>/dev/null
    return 1
  fi
  printf '%s\n' "$pid" > "$pidfile"
  return 0
}

# --- hub tespiti: bridge.js Auto-detect kuralinin birebir aynisi -------------
# OR kurallari: path ttyUSB | path ttyACM | vendorId 10c4 (CP210x).
# serialport bridge node_modules'undan cozumlenir.
hub_candidates() {
  NODE_PATH="$BACKEND_DIR/node_modules" node -e '
    const { SerialPort } = require("serialport");
    (async () => {
      try {
        const ports = await SerialPort.list();
        const hits = ports.filter((p) =>
          (p.path && (p.path.includes("ttyUSB") || p.path.includes("ttyACM"))) ||
          (p.vendorId && p.vendorId.toLowerCase() === "10c4")
        );
        console.log(hits.map((p) => p.path).join("\n"));
      } catch (e) {
        console.error("SERIALDETECTERROR:" + e.message);
        process.exit(4);
      }
    })();
  ' 2>/dev/null
}
# not: node hata sonucu rc=4 doner; iletisi dev null duser, arayan rc'yi bakar.

# ================================ START =====================================
cmd_start() {
  acquire_lock

  local force_mock="" force_port=""
  for arg in "$@"; do
    case "$arg" in
      --mock) force_mock="1" ;;
      --port=*) force_port="${arg#--port=}" ;;
      *) fail "Bilinmeyen arguman: $arg (desteklenen: --mock, --port=/dev/ttyX)" 2 ;;
    esac
  done
  if [ -n "$force_mock" ] && [ -n "$force_port" ]; then
    fail "--mock ve --port ayni anda kullanilamaz." 2
  fi

  # ---- Backend ----
  local be_pid be_new=0
  if backend_alive; then
    be_pid="$(read_pid "$BE_PID_FILE")"
    say "RPT: Backend zaten bu scriptin kaydiyla calisiyor (pid $be_pid)."
  elif port_busy; then
    say "ERR: Port $SERVER_PORT zaten kullaniliyor VEYA o surec bu scriptin kayitli degil."
    say "     asset-control baska sureci durdurmaz/sahiplenmez; cakisma bildirildi."
    say "     Tespit: curl -s http://127.0.0.1:$SERVER_PORT/api/health veya "
    say "             ss -ltnp | grep :$SERVER_PORT"
    exit 5
  else
    say "INF: Backend baslatiliyor (node server.js, MONGODB_URI yerel gelistirme kurali)..."
    say "     ADMIN_API_KEY / INGEST_API_KEY script tarafindan ayarlanmaz; .env yuklemesi surecin kendisinde."
    if ! launch_bg "$BE_LOG" "$BACKEND_DIR" "$BE_PID_FILE" \
         env MONGODB_URI="$MONGO_URI" node "$SERVER_JS"; then
      fail "Backend baslatilamadi." 6
    fi
    be_pid="$(read_pid "$BE_PID_FILE")"
    say "INF: Backend pid $be_pid (log: $BE_LOG)"
  fi

  # ---- Backend saglikin ozlemi ----
  local waited=0 code="" deadline=$((BACKEND_READY_TIMEOUT * 10))
  while [ "$waited" -lt "$deadline" ]; do
    if ! backend_alive; then
      say "ERR: Backend beklenmeyen sekilde durdu (pid $(read_pid "$BE_PID_FILE"))."
      say "     Backend log son satirlari:"
      tail -n 8 "$BE_LOG" 2>/dev/null | sed 's/^/       /'
      exit 6
    fi
    code="$(backend_health_code)"
    if [ "$code" = "200" ]; then break; fi
    sleep 0.4
    waited=$((waited + 1))
  done
  if [ "$code" != "200" ]; then
    say "ERR: Backend $BACKEND_READY_TIMEOUT sn icinde /api/health 200 donmedi (son kod ${code:-yok})."
    say "     503 geneldi: DB/Redis hazir-degil; MongoDB calisiyor mu (mongod)?"
    tail -n 8 "$BE_LOG" 2>/dev/null | sed 's/^/       /'
    exit 6
  fi
  say "OKK: Backend hazir: http://127.0.0.1:$SERVER_PORT/api/health -> 200 (pid $(read_pid "$BE_PID_FILE"))."

  # ---- Bridge ----
  if bridge_alive; then
    local cmd mode
    cmd="$(bridge_cmdline)"
    mode="$(bridge_mode_from_cmdline "$cmd")"
    say "RPT: Bridge zaten calisiyor (pid $(read_pid "$BR_PID_FILE"), mod: $mode)."
    say "Tamamlandi."
    return 0
  fi

  local mode port=""
  local candidates det_rc
  if [ -n "$force_mock" ]; then
    mode="mock"
  else
    candidates="$(hub_candidates)"
    det_rc=$?
    if [ "$det_rc" -ne 0 ]; then
      say "ERR: Hub taramasi yapilamadi (serialport listesi). Mod secilmedi; bridge baslatilmadi."
      say "     Backend karsildigi gibi calisiyor (pid $(read_pid "$BE_PID_FILE"))."
      exit 8
    fi
    if [ -n "$force_port" ]; then
      mode="live:$force_port"
    else
      local count
      count="$(printf '%s' "$candidates" | sed '/^$/d' | wc -l | tr -d ' ')"
      if [ "$count" = "0" ]; then
        mode="mock"
      elif [ "$count" = "1" ]; then
        mode="live:$candidates"
      else
        say "ERR: Belirsizlik - birden fazla olasi hub adiyi bulundu, rastgele secim yapilmaz."
        printf '%s\n' "$candidates" | sed '/^$/d; s/^/     - /'
        say "     Acik secim icin: ./asset-control.sh start --port=/dev/ttyUSB0"
        say "     (Backend calisiyor, pid $(read_pid "$BE_PID_FILE"); bridge baslatilmadi.)"
        exit 7
      fi
    fi
  fi

  local br_args=""
  case "$mode" in
    mock)   br_args="--mock"; say "INF: Seri port adayi bulunamadi -> bridge MOCK modda baslatiliyor..." ;;
    live:*) port="${mode#live:}"; br_args="--port=$port"
            say "INF: Hub adasi tespit edildi -> bridge CANLI seri modda baslatiliyor..." ;;
  esac

  local br_pid
  if ! launch_bg "$BR_LOG" "$BACKEND_DIR" "$BR_PID_FILE" \
       env node "$BRIDGE_JS" "$br_args"; then
    fail "Bridge baslatilamadi." 6
  fi
  br_pid="$(read_pid "$BR_PID_FILE")"
  say "INF: Bridge pid $br_pid (log: $BR_LOG)"
  say "Det: backend pid $(read_pid "$BE_PID_FILE") | bridge pid $br_pid | mod $mode"

  # ---- dogrulamamareye -----
  local w=0 limit
  if [ "$mode" = "mock" ]; then
    limit=$((15 * 10))
    mock_ok=0
    while [ "$w" -lt "$limit" ]; do
      if grep -q "Çalışma Modu: MOCK" "$BR_LOG" 2>/dev/null; then mock_ok=1; break; fi
      if ! proc_valid "$br_pid" "bridge/bridge.js"; then
        say "ERR: Bridge beklenmedik sekilde durdu (mock). Log son satirlari:"
        tail -n 8 "$BR_LOG" 2>/dev/null | sed 's/^/       /'
        : > "$BR_PID_FILE"
        exit 6
      fi
      sleep 0.3
      w=$((w + 1))
    done
    if [ "$mock_ok" -ne 1 ]; then
      say "ERR: Bridge mock acilis onayi (Calisma Modu: MOCK) $((limit / 10)) sn icinde logda gorulmedi."
      tail -n 8 "$BR_LOG" 2>/dev/null | sed 's/^/       /'
      stop_group "Bridge " "$BR_PID_FILE" "bridge/bridge.js" >/dev/null 2>&1 || true
      exit 9
    fi
    printf 'mock\n' > "$BR_MODE_FILE"
    say "OKK: Bridge MOCK modda calisiyor (pid $br_pid)."
    say "     Panel: http://localhost:$SERVER_PORT/admin - Portal: http://localhost:$SERVER_PORT/"
    return 0
  fi

  limit=$((LIVE_OPEN_TIMEOUT * 10))
  opened=0
  first_fail_line=""
  while [ "$w" -lt "$limit" ]; do
    if grep -q "Seri port acildi" "$BR_LOG" 2>/dev/null; then opened=1; break; fi
    first_fail_line="$(grep -m1 -E 'Seri port hatasi|Port acilirken hata|Seri port baslatilamadi' "$BR_LOG" 2>/dev/null)"
    if [ -n "$first_fail_line" ]; then break; fi
    if ! proc_valid "$br_pid" "bridge/bridge.js"; then
      say "ERR: Bridge beklenmedik sekilde durdu (canli). Log son satirlari:"
      tail -n 8 "$BR_LOG" 2>/dev/null | sed 's/^/       /'
      : > "$BR_PID_FILE"
      exit 9
    fi
    sleep 0.1
    w=$((w + 1))
  done

  if [ "$opened" -ne 1 ]; then
    say "ERR: Hub/port $port acilisi LOGDA ONAYLANMADI - mock'a sessiz gecis YOK."
    if [ -n "$first_fail_line" ]; then
      say "     Sebep (bridge log): $first_fail_line"
    else
      say "     Neden: $LIVE_OPEN_TIMEOUT sn icinde 'Seri port acildi' onayi gelmedi."
    fi
    say "     Sik nedenler: dergi yetkisi (dialout grubu/dev udev), port bembaska bir program tarafindan msgul."
    tail -n 6 "$BR_LOG" 2>/dev/null | sed 's/^/       /'
    say "     Bridge durduruluyor (backend calismaya devam ediyor)..."
    stop_group "Bridge" "$BR_PID_FILE" "bridge/bridge.js" >/dev/null 2>&1 || true
    exit 9
  fi

  printf 'live:%s\n' "$port" > "$BR_MODE_FILE"
  say "OKK: Bridge CANLI modda calisiyor: $port (pid $br_pid)."
  say "     Panel: http://localhost:$SERVER_PORT/admin - Portal: http://localhost:$SERVER_PORT/"
}

# ================================ STOP ======================================
cmd_stop() {
  acquire_lock
  stop_group "Bridge"  "$BR_PID_FILE" "bridge/bridge.js" || true
  stop_group "Backend" "$BE_PID_FILE" "server.js" || true
  printf 'stopped\n' > "$BR_MODE_FILE"
  say "OKK: Stop tamamlandi (yalnizca bu scriptin kayitli surecleri etkilendi)."
}

# ================================ STATUS ====================================
cmd_status() {
  local bepid brpid code mode
  bepid="$(read_pid "$BE_PID_FILE")"
  brpid="$(read_pid "$BR_PID_FILE")"

  if backend_alive; then
    code="$(backend_health_code)"
    say "Backend: CALISIYOR (pid $bepid) | health=$code | port=$SERVER_PORT | log=$BE_LOG"
  else
    say "Backend: calismiyor"
  fi

  if bridge_alive; then
    mode="$(bridge_mode_from_cmdline "$(bridge_cmdline)")"
    case "$mode" in
      mock)    say "Bridge : CALISIYOR (pid $brpid) | mod=MOCK (sanal akis) | log=$BR_LOG" ;;
      live:*)  say "Bridge : CALISIYOR (pid $brpid) | mod=CANLI | port=${mode#live:} | log=$BR_LOG" ;;
      *)       say "Bridge : CALISIYOR (pid $brpid) | mod=bunde bilmiyorum (cmdline'da port/mock yazi kasiyor)" ;;
    esac
    if tail -n 200 "$BR_LOG" 2>/dev/null | grep -q "Seri port kapandi"; then
      say "         UYARI: bridge logunda yakin zamanda port kapanma kaydi var."
    fi
    if tail -n 200 "$BR_LOG" 2>/dev/null | grep -q "Seri port hatasi"; then
      say "         UYARI: bridge logunda yakin zamanda port hatasi kaydi var."
    fi
  else
    say "Bridge : calismiyor"
  fi

  if ! backend_alive && ! bridge_alive; then
    say "Durum  : kayitli surec yok. (Baslatma: ./asset-control.sh start)"
  fi
}

# ================================ GİRİŞ =====================================
case "${1:-}" in
  start)  cmd_start "${@:2}" ;;
  stop)   cmd_stop ;;
  status) cmd_status ;;
  ""|help|-h|--help)
    say "Kullanim:"
    say "  ./asset-control.sh start [--mock | --port=/dev/ttyUSB0]"
    say "  ./asset-control.sh stop"
    say "  ./asset-control.sh status"
    ;;
  *) fail "Bilinmeyen komut: '$1'. (start | stop | status)" 2 ;;
esac
