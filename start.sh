#!/usr/bin/env bash
set -Eeuo pipefail

: "${WALLET:?Set WALLET in .env to your own Monero wallet address}"

POOL="${POOL:-xmr-us.kryptex.network:7029}"
PASSWORD="${PASSWORD:-x}"
CPU_HINT="${CPU_HINT:-75}"
DONATE_LEVEL="${DONATE_LEVEL:-1}"
TLS="${TLS:-false}"

if ! [[ "$CPU_HINT" =~ ^[0-9]+$ ]] || (( CPU_HINT < 1 || CPU_HINT > 100 )); then
  echo "ERROR: CPU_HINT must be an integer from 1 to 100." >&2
  exit 2
fi
if ! [[ "$DONATE_LEVEL" =~ ^[0-9]+$ ]] || (( DONATE_LEVEL < 1 || DONATE_LEVEL > 100 )); then
  echo "ERROR: DONATE_LEVEL must be an integer from 1 to 100." >&2
  exit 2
fi

host="${POOL%:*}"
port="${POOL##*:}"
if [[ "$POOL" != *:* || -z "$host" || ! "$port" =~ ^[0-9]+$ ]]; then
  echo "ERROR: POOL must be hostname:port, for example xmr-us.kryptex.network:7029" >&2
  exit 2
fi

echo "Starting XMRig"
echo "Pool: $POOL"
echo "CPU thread hint: ${CPU_HINT}% (approximate, not a hard CPU cap)"
echo "Hashrate will be printed every 10 seconds."
echo "Stop with: docker stop xmr-miner"

args=(
  --coin=monero
  --url="$POOL"
  --user="$WALLET"
  --pass="$PASSWORD"
  --donate-level="$DONATE_LEVEL"
  --cpu-max-threads-hint="$CPU_HINT"
  --print-time=10
  --no-color
)

if [[ "${TLS,,}" == "true" ]]; then
  args+=(--tls)
fi

exec /usr/local/bin/xmrig "${args[@]}"
