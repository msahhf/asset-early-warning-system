#!/usr/bin/env bash
# ==============================================================================
# ASSET 2.1 - Backend + Bridge single-command control script
#
# Run from the repository root (assetaydem). Layout:
#   backend/ (server.js + src/ + public/ + bridge/) | iot/ (firmware)
#   docs/ | 3d_files/
# Usage:
#   ./asset-control.sh start [--mock | --port=/dev/ttyUSB0]
#   ./asset-control.sh stop
#   ./asset-control.sh status
#
# Behavior:
#   start: starts the backend once (node server.js, the same app as npm run dev;
#          no nodemon watcher, keeping process ownership deterministic).
#          Health check: GET /api/health (expects 200).
#          Hub detection exactly matches the rule in the bridge code
#          (bridge.js ~321-327, auto-detect; OR rules):
#          path ttyUSB | path ttyACM | vendorId 10c4 (CP210x). Then:
#             no hub              -> bridge --mock
#             exactly one candidate -> bridge --port=<path> (live)
#             multiple candidates -> no random selection; report ambiguity
#                                     (user selects explicitly with --port=)
#             hub cannot be opened -> no silent fallback to mock; report the reason
#   stop : ONLY stops processes recorded in this script's pid files (their own
#          setsid process group). No pgrep/pkill; without a recorded
#          pid + pgid validation + cmdline match, no process is
#          touched. Existing user/systemd processes on the system
#          are not affected.
#   status: status of recorded processes + bridge mode + backend health.
#
# NOT: ADMIN_API_KEY / INGEST_API_KEY are not set or printed by this script;
#      backend and bridge load their own .env files. Only the local
#      The local development MongoDB URI is passed via the process environment:
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

BACKEND_READY_TIMEOUT=30   # sec: MongoDB 5s + rehydrate ~4s + margin
LIVE_OPEN_TIMEOUT=12       # sec: wait for the "Serial port opened" log confirmation
STOP_GRACE=7               # sn: SIGTERM then SIGKILL

say()  { printf '%s\n' "$*"; }
fail() { printf '%s\n' "ERROR: $*" >&2; exit "${2:-1}"; }
note() { printf '%s\n' "WARNING: $*" >&2; }

for t in bash curl node setsid flock grep awk sed tail; do
  command -v "$t" >/dev/null 2>&1 || fail "Required tool not found: $t" 127
done

[ -f "$SERVER_JS" ] || fail "Backend not found: $SERVER_JS (run the script from the project root)"
[ -f "$BRIDGE_JS" ] || fail "Bridge not found: $BRIDGE_JS"

mkdir -p "$STATE_DIR" 2>/dev/null || fail "Could not create state directory: $STATE_DIR"

# --- lock: prevent concurrent start/stop operations ------------------------------
# Note: do not use 2>/dev/null on the exec line; exec redirection changes
# stderr for the whole script and would hide error messages.
acquire_lock() {
  [ -w "$STATE_DIR" ] || fail "No write permission for state directory: $STATE_DIR" 1
  exec 9>"$STATE_DIR/.lock"   # bash reports an error and exits if this cannot be opened
  flock -n 9 || fail "Another asset-control start/stop is still running (lock busy). Wait and retry." 1
}

# --- process helpers (NO pgrep/pkill) -------------------------------------
read_pid() {
  local p
  p="$(head -n1 "$1" 2>/dev/null | tr -cd '0-9')"
  printf '%s' "$p"
}

# proc_stat_field <pid> <field index after the final ' )'>: pgrp is field 3
stat_pgrp() {
  local pid="$1" f
  f="$(cat "/proc/$pid/stat" 2>/dev/null)" || { printf ''; return; }
  # avoid parentheses/spaces in comm: after the last ')': state ppid pgrp
  printf '%s\n' "$f" | sed 's/^.*) //' | awk '{print $3}'
}

# proc_valid <pid> <required-cmdline> -> 0: alive, matching, group leader
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

# port_busy: quick TCP connection attempt to 127.0.0.1:PORT (any service)
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

# stop_group <label> <pid_file> <cmdline_match>
#   Stops the process GROUP only when the recorded pid + pgid==pid + cmdline match hold
#   (our own group created with setsid). Does not touch any other process.
stop_group() {
  local label="$1" pidfile="$2" must="$3"
  local pid pgid waited=0 rc=1
  pid="$(read_pid "$pidfile")"
  if [ -z "$pid" ]; then
    say "MID: $label - no record (pid file is empty/missing)."
    return 0
  fi
  if ! proc_valid "$pid" "$must"; then
    say "BRK: $label - recorded pid $pid not alive/stale (untouched; refreshing pid file)."
    : > "$pidfile"
    return 0
  fi
  pgid="$(stat_pgrp "$pid")"
  if [ "$pgid" != "$pid" ]; then
    # pid reuse risk: it is no longer our group leader. DO NOT STOP; leave untouched!
    note "$label - pid $pid is no longer the expected group leader (pgid=$pgid). Not stopped; inspect manually."
    : > "$pidfile"
    return 1
  fi
  say "STP: $label stopping (pid $pid, process group $pgid, SIGTERM)..."
  kill -TERM -- "-$pgid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null
  while [ "$waited" -lt $((STOP_GRACE * 10)) ]; do
    if ! [ -e "/proc/$pid" ]; then rc=0; break; fi
    sleep 0.1
    waited=$((waited + 1))
    if [ "$waited" -ge $((STOP_GRACE * 10)) ]; then break; fi
  done
  if [ "$rc" -ne 0 ] && [ -e "/proc/$pid" ]; then
    say "WRN: $label - SIGTERM was insufficient (process group $pgid), SIGKILL..."
    kill -KILL -- "-$pgid" 2>/dev/null || kill -KILL "$pid" 2>/dev/null
    sleep 0.3
    if [ -e "/proc/$pid" ]; then
      note "$label - still alive after SIGKILL; manual intervention may be required ($pid)."
      return 1
    fi
  fi
  : > "$pidfile"
  say "OKK: $label stopped."
  return 0
}

# launch_bg <log_file> <working_directory> <pid_file> <command...>
#   Starts the process in its own setsid group and writes output to a log; stores its pid
#   in the pid file (read only from that file, never captured). fd9 (flock)
#   is closed for child processes (do not inherit the lock). rc=0 success, rc=1 error.
#   Dikkat: Do not pass setsid to callers (one setsid only; double setsid forks and confuses the pid
#   ). Child process: env/argument form is unrestricted.
launch_bg() {
  local logfile="$1" workdir="$2" pidfile="$3"; shift 3
  local pid pgid tries=0
  ( cd "$workdir" && exec setsid "$@" ) 9>&- >"$logfile" 2>&1 &
  pid="$!"
  # Race handling: the background subshell execs setsid within a few ms, making pgid equal pid.
  #   One read may be too early; retry the condition check for up to 2 seconds.
  pgid=""
  while [ "$tries" -lt 20 ]; do
    pgid="$(ps -o pgid= -p "$pid" 2>/dev/null | tr -d ' ')"
    [ -n "$pgid" ] && [ "$pgid" = "$pid" ] && break
    if ! [ -e "/proc/$pid" ]; then
      printf '%s\n' "Internal error: started process disappeared (pid $pid)." >&2
      return 1
    fi
    sleep 0.1
    tries=$((tries + 1))
  done
  if [ "$pgid" != "$pid" ]; then
    printf '%s\n' "Internal error: process started without being a group leader ($pid, pgid=$pgid). Stopping..." >&2
    kill -TERM "$pid" 2>/dev/null
    return 1
  fi
  printf '%s\n' "$pid" > "$pidfile"
  return 0
}

# --- hub detection: exactly matches bridge.js auto-detect rule -------------
# OR rules: path ttyUSB | path ttyACM | vendorId 10c4 (CP210x).
# Resolve serialport from bridge node_modules.
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
# Note: node returns rc=4 on error; its message is redirected to /dev/null, caller checks rc.

# ================================ START =====================================
cmd_start() {
  acquire_lock

  local force_mock="" force_port=""
  for arg in "$@"; do
    case "$arg" in
      --mock) force_mock="1" ;;
      --port=*) force_port="${arg#--port=}" ;;
      *) fail "Unknown argument: $arg (supported: --mock, --port=/dev/ttyX)" 2 ;;
    esac
  done
  if [ -n "$force_mock" ] && [ -n "$force_port" ]; then
    fail "--mock and --port cannot be used together." 2
  fi

  # ---- Backend ----
  local be_pid be_new=0
  if backend_alive; then
    be_pid="$(read_pid "$BE_PID_FILE")"
    say "RPT: Backend is already running under this script's record (pid $be_pid)."
  elif port_busy; then
    say "ERR: Port $SERVER_PORT is already in use OR that process is not recorded by this script."
    say "     asset-control will not stop or claim another process; conflict reported."
    say "     Check with: curl -s http://127.0.0.1:$SERVER_PORT/api/health veya "
    say "             ss -ltnp | grep :$SERVER_PORT"
    exit 5
  else
    say "INF: Starting backend (node server.js, MONGODB_URI local development rule)..."
    say "     ADMIN_API_KEY / INGEST_API_KEY are not set by the script; the process loads .env itself."
    if ! launch_bg "$BE_LOG" "$BACKEND_DIR" "$BE_PID_FILE" \
         env MONGODB_URI="$MONGO_URI" node "$SERVER_JS"; then
      fail "Could not start backend." 6
    fi
    be_pid="$(read_pid "$BE_PID_FILE")"
    say "INF: Backend pid $be_pid (log: $BE_LOG)"
  fi

  # ---- Wait for backend health ----
  local waited=0 code="" deadline=$((BACKEND_READY_TIMEOUT * 10))
  while [ "$waited" -lt "$deadline" ]; do
    if ! backend_alive; then
      say "ERR: Backend stopped unexpectedly (pid $(read_pid "$BE_PID_FILE"))."
      say "     Last backend log lines:"
      tail -n 8 "$BE_LOG" 2>/dev/null | sed 's/^/       /'
      exit 6
    fi
    code="$(backend_health_code)"
    if [ "$code" = "200" ]; then break; fi
    sleep 0.4
    waited=$((waited + 1))
  done
  if [ "$code" != "200" ]; then
    say "ERR: Backend $BACKEND_READY_TIMEOUT sec; /api/health did not return 200 (last code ${code:-none})."
    say "     503 usually means DB/Redis not ready; is MongoDB running (mongod)?"
    tail -n 8 "$BE_LOG" 2>/dev/null | sed 's/^/       /'
    exit 6
  fi
  say "OKK: Backend ready: http://127.0.0.1:$SERVER_PORT/api/health -> 200 (pid $(read_pid "$BE_PID_FILE"))."

  # ---- Bridge ----
  if bridge_alive; then
    local cmd mode
    cmd="$(bridge_cmdline)"
    mode="$(bridge_mode_from_cmdline "$cmd")"
    say "RPT: Bridge is already running (pid $(read_pid "$BR_PID_FILE"), mode: $mode)."
    say "Done."
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
      say "ERR: Could not scan for a hub (serialport list). No mode selected; bridge was not started."
      say "     Backend remains running (pid $(read_pid "$BE_PID_FILE"))."
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
        say "ERR: Ambiguous hub detection - multiple possible hub candidates found; no random selection will be made."
        printf '%s\n' "$candidates" | sed '/^$/d; s/^/     - /'
        say "     To select explicitly: ./asset-control.sh start --port=/dev/ttyUSB0"
        say "     (Backend remains running, pid $(read_pid "$BE_PID_FILE"); bridge not started.)"
        exit 7
      fi
    fi
  fi

  local br_args=""
  case "$mode" in
    mock)   br_args="--mock"; say "INF: No serial port candidate found -> starting bridge in MOCK mode..." ;;
    live:*) port="${mode#live:}"; br_args="--port=$port"
            say "INF: Hub candidate detected -> starting bridge in LIVE serial mode..." ;;
  esac

  local br_pid
  if ! launch_bg "$BR_LOG" "$BACKEND_DIR" "$BR_PID_FILE" \
       env node "$BRIDGE_JS" "$br_args"; then
    fail "Could not start bridge." 6
  fi
  br_pid="$(read_pid "$BR_PID_FILE")"
  say "INF: Bridge pid $br_pid (log: $BR_LOG)"
  say "Info: backend pid $(read_pid "$BE_PID_FILE") | bridge pid $br_pid | mod $mode"

  # ---- Verify startup -----
  local w=0 limit
  if [ "$mode" = "mock" ]; then
    limit=$((15 * 10))
    mock_ok=0
    while [ "$w" -lt "$limit" ]; do
      if grep -q "Operating mode: MOCK" "$BR_LOG" 2>/dev/null; then mock_ok=1; break; fi
      if ! proc_valid "$br_pid" "bridge/bridge.js"; then
        say "ERR: Bridge stopped unexpectedly (mock). Last log lines:"
        tail -n 8 "$BR_LOG" 2>/dev/null | sed 's/^/       /'
        : > "$BR_PID_FILE"
        exit 6
      fi
      sleep 0.3
      w=$((w + 1))
    done
    if [ "$mock_ok" -ne 1 ]; then
      say "ERR: Bridge mock startup confirmation (Operating mode: MOCK) $((limit / 10)) not found in the log within the timeout."
      tail -n 8 "$BR_LOG" 2>/dev/null | sed 's/^/       /'
      stop_group "Bridge " "$BR_PID_FILE" "bridge/bridge.js" >/dev/null 2>&1 || true
      exit 9
    fi
    printf 'mock\n' > "$BR_MODE_FILE"
    say "OKK: Bridge is running in MOCK mode (pid $br_pid)."
    say "     Panel: http://localhost:$SERVER_PORT/admin - Portal: http://localhost:$SERVER_PORT/"
    return 0
  fi

  limit=$((LIVE_OPEN_TIMEOUT * 10))
  opened=0
  first_fail_line=""
  while [ "$w" -lt "$limit" ]; do
    if grep -q "Serial port opened" "$BR_LOG" 2>/dev/null; then opened=1; break; fi
    first_fail_line="$(grep -m1 -E 'Serial port error|Error opening port|Could not start serial port' "$BR_LOG" 2>/dev/null)"
    if [ -n "$first_fail_line" ]; then break; fi
    if ! proc_valid "$br_pid" "bridge/bridge.js"; then
      say "ERR: Bridge stopped unexpectedly (live). Last log lines:"
      tail -n 8 "$BR_LOG" 2>/dev/null | sed 's/^/       /'
      : > "$BR_PID_FILE"
      exit 9
    fi
    sleep 0.1
    w=$((w + 1))
  done

  if [ "$opened" -ne 1 ]; then
    say "ERR: Hub/port $port startup was NOT CONFIRMED IN THE LOG — no silent fallback to mock."
    if [ -n "$first_fail_line" ]; then
      say "     Reason (bridge log): $first_fail_line"
    else
      say "     Reason: $LIVE_OPEN_TIMEOUT within timeout 'Serial port opened' was not confirmed."
    fi
    say "     Common causes: device permissions (dialout group/udev), or the port is busy in another program."
    tail -n 6 "$BR_LOG" 2>/dev/null | sed 's/^/       /'
    say "     Bridge stopping (backend remains running)..."
    stop_group "Bridge" "$BR_PID_FILE" "bridge/bridge.js" >/dev/null 2>&1 || true
    exit 9
  fi

  printf 'live:%s\n' "$port" > "$BR_MODE_FILE"
  say "OKK: Bridge is running in LIVE mode: $port (pid $br_pid)."
  say "     Panel: http://localhost:$SERVER_PORT/admin - Portal: http://localhost:$SERVER_PORT/"
}

# ================================ STOP ======================================
cmd_stop() {
  acquire_lock
  stop_group "Bridge"  "$BR_PID_FILE" "bridge/bridge.js" || true
  stop_group "Backend" "$BE_PID_FILE" "server.js" || true
  printf 'stopped\n' > "$BR_MODE_FILE"
  say "OKK: Stop complete (only processes recorded by this script were affected)."
}

# ================================ STATUS ====================================
cmd_status() {
  local bepid brpid code mode
  bepid="$(read_pid "$BE_PID_FILE")"
  brpid="$(read_pid "$BR_PID_FILE")"

  if backend_alive; then
    code="$(backend_health_code)"
    say "Backend: RUNNING (pid $bepid) | health=$code | port=$SERVER_PORT | log=$BE_LOG"
  else
    say "Backend: stopped"
  fi

  if bridge_alive; then
    mode="$(bridge_mode_from_cmdline "$(bridge_cmdline)")"
    case "$mode" in
      mock)    say "Bridge: RUNNING (pid $brpid) | mode=MOCK (virtual stream) | log=$BR_LOG" ;;
      live:*)  say "Bridge: RUNNING (pid $brpid) | mode=LIVE | port=${mode#live:} | log=$BR_LOG" ;;
      *)       say "Bridge: RUNNING (pid $brpid) | mode=unknown (no port/mock argument found in cmdline)" ;;
    esac
    if tail -n 200 "$BR_LOG" 2>/dev/null | grep -q "Serial port closed"; then
      say "         WARNING: recent port-close event found in bridge log."
    fi
    if tail -n 200 "$BR_LOG" 2>/dev/null | grep -q "Serial port error"; then
      say "         WARNING: recent port error found in bridge log."
    fi
  else
    say "Bridge: stopped"
  fi

  if ! backend_alive && ! bridge_alive; then
    say "Status : no recorded process. (Start: ./asset-control.sh start)"
  fi
}

# ================================ ENTRY =====================================
case "${1:-}" in
  start)  cmd_start "${@:2}" ;;
  stop)   cmd_stop ;;
  status) cmd_status ;;
  ""|help|-h|--help)
    say "Usage:"
    say "  ./asset-control.sh start [--mock | --port=/dev/ttyUSB0]"
    say "  ./asset-control.sh stop"
    say "  ./asset-control.sh status"
    ;;
  *) fail "Unknown command: '$1'. (start | stop | status)" 2 ;;
esac
