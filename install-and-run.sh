#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")"

command -v docker >/dev/null 2>&1 || {
  echo "Docker is not installed. Install Docker Engine first: https://docs.docker.com/engine/install/ubuntu/"
  exit 1
}
docker info >/dev/null

if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "Created .env. Edit it and set WALLET, then run this script again."
  exit 0
fi

if grep -q 'PASTE_YOUR_MONERO_WALLET_ADDRESS_HERE' .env; then
  echo "Edit .env and replace the placeholder WALLET first."
  exit 1
fi

docker build -t xmr-miner:local .
docker rm -f xmr-miner >/dev/null 2>&1 || true
docker run -d \
  --name xmr-miner \
  --init \
  --restart unless-stopped \
  --stop-timeout 30 \
  --env-file .env \
  xmr-miner:local

echo
echo "Container started. Follow logs with:"
echo "  docker logs -f xmr-miner"
echo "Stop with:"
echo "  docker stop xmr-miner"
