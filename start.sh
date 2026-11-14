#!/usr/bin/env bash
set -Eeuo pipefail

: "${WALLET:?Set WALLET in .env or Docker environment}"
PASSWORD="${PASSWORD:-x}"
TLS="${TLS:-false}"
DONATE_LEVEL="${DONATE_LEVEL:-1}"

MIN_CPU="${MIN_CPU:-75}"
MAX_CPU="${MAX_CPU:-85}"
MIN_PING_INTERVAL="${MIN_PING_INTERVAL:-15}"
MAX_PING_INTERVAL="${MAX_PING_INTERVAL:-45}"
POOL_CHECK_TIMEOUT="${POOL_CHECK_TIMEOUT:-3}"

# Configure up to ten endpoints as POOL_1 ... POOL_10.
# Format: hostname:port (IPv6 literals are not supported by this simple parser).
POOLS=()
for i in {1..10}; do
  var="POOL_${i}"
  value="${!var:-}"
  [[ -n "$value" ]] && POOLS+=("$value")
done

if (( ${#POOLS[@]} == 0 )); then
  echo "ERROR: Configure at least one pool using POOL_1 ... POOL_10." >&2
  exit 1
fi

SITES=(
  google.com cloudflare.com github.com wikipedia.org debian.org
  archlinux.org microsoft.com openai.com kernel.org gnu.org
)

MINER_PID=""
PING_PID=""

log() {
  # Keep diagnostic output off stdout: select_best_pool is used in
  # command substitution, whose stdout must contain only the chosen host:port.
  printf '[%s] %s\n' "$(date '+%F %T')" "$*" >&2
}

cleanup() {
  log "Stopping processes..."
  [[ -n "$MINER_PID" ]] && kill "$MINER_PID" 2>/dev/null || true
  [[ -n "$PING_PID" ]] && kill "$PING_PID" 2>/dev/null || true
  [[ -n "$MINER_PID" ]] && wait "$MINER_PID" 2>/dev/null || true
  [[ -n "$PING_PID" ]] && wait "$PING_PID" 2>/dev/null || true
  exit 0
}
trap cleanup TERM INT

if (( MIN_CPU < 1 || MAX_CPU > 100 || MIN_CPU > MAX_CPU )); then
  log "Invalid CPU range."
  exit 1
fi
if (( MIN_PING_INTERVAL < 1 || MAX_PING_INTERVAL < MIN_PING_INTERVAL )); then
  log "Invalid ping interval range."
  exit 1
fi

# Test TCP connection latency for every configured pool and select the
# lowest-latency endpoint that accepts a connection.
select_best_pool() {
  local best_pool="" best_ms=999999 pool host port start end elapsed
  for pool in "${POOLS[@]}"; do
    if [[ "$pool" != *:* ]]; then
      log "Skipping invalid pool endpoint (expected host:port): $pool"
      continue
    fi

    host="${pool%:*}"
    port="${pool##*:}"
    [[ -n "$host" && "$port" =~ ^[0-9]+$ ]] || {
      log "Skipping invalid pool endpoint: $pool"
      continue
    }

    start=$(date +%s%N)
    if timeout "$POOL_CHECK_TIMEOUT" bash -c 'exec 3<>"/dev/tcp/$1/$2"' _ "$host" "$port" 2>/dev/null; then
      end=$(date +%s%N)
      elapsed=$(( (end - start) / 1000000 ))
      log "Pool reachable: $pool (${elapsed} ms)"
      if (( elapsed < best_ms )); then
        best_ms="$elapsed"
        best_pool="$pool"
      fi
    else
      log "Pool unavailable: $pool"
    fi
  done

  if [[ -z "$best_pool" ]]; then
    log "No pool is reachable; retrying in 20 seconds."
    return 1
  fi

  printf '%s\n' "$best_pool"
}

ping_worker() {
  while true; do
    site="${SITES[RANDOM % ${#SITES[@]}]}"
    log "PING -> ${site}"
    ping -n -c 1 -W 3 "$site" 2>&1 |
      grep -E 'bytes from|100% packet loss|unknown host|Temporary failure' || true
    delay=$((MIN_PING_INTERVAL + RANDOM % (MAX_PING_INTERVAL - MIN_PING_INTERVAL + 1)))
    sleep "$delay"
  done
}

ping_worker &
PING_PID=$!
log "Random ping worker started (PID ${PING_PID})"

while true; do
  if ! selected_pool="$(select_best_pool)"; then
    sleep 20
    continue
  fi

  cpu_hint=$((MIN_CPU + RANDOM % (MAX_CPU - MIN_CPU + 1)))
  log "Selected lowest-latency pool: ${selected_pool}"
  log "Starting XMRig with CPU thread hint ${cpu_hint}%"

  miner_args=(
    --coin=monero
    --url="$selected_pool"
    --user="$WALLET"
    --pass="$PASSWORD"
    --donate-level="$DONATE_LEVEL"
    --cpu-max-threads-hint="$cpu_hint"
    --print-time=60
  )
  [[ "${TLS,,}" == "true" ]] && miner_args+=(--tls)

  /usr/local/bin/xmrig "${miner_args[@]}" &
  MINER_PID=$!

  # Recheck pool and vary CPU hint every 5–15 minutes.
  duration=$((300 + RANDOM % 601))
  log "Next pool/CPU selection in ${duration}s"
  sleep "$duration" &
  timer_pid=$!
  wait "$timer_pid" || true

  log "Stopping XMRig to reselect the best pool and CPU hint..."
  kill -TERM "$MINER_PID" 2>/dev/null || true
  wait "$MINER_PID" 2>/dev/null || true
  MINER_PID=""
done
