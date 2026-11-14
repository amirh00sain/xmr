# XMRig Docker miner with pool selection

This package contains:
- `Dockerfile` — builds XMRig from upstream source.
- `start.sh` — tests up to ten configured pool endpoints, selects the one
  with the lowest successful TCP connection latency, runs XMRig, and pings
  random public hosts in parallel.
- `.env.example` — wallet and pool configuration template.

## Configure

Copy `.env.example` to `.env` and edit it:

```bash
cp .env.example .env
nano .env
```

Set `WALLET` to your own Monero wallet address. Replace the ten example
pool endpoints with real `hostname:port` endpoints from pool operators.
The `.example.com` entries are placeholders and will not connect.

## Build and run

```bash
docker build -t xmr-miner .
docker run -d --name xmr-miner --restart unless-stopped --env-file .env xmr-miner
```

Logs and stop:

```bash
docker logs -f xmr-miner
docker stop xmr-miner
```

The script checks all configured endpoints at startup and then rechecks
when it restarts XMRig (every 5–15 minutes). It chooses the lowest TCP
connect latency among reachable endpoints. TCP latency is only a quick
network metric; it does not guarantee the highest pool payout or share
acceptance rate. Use pool endpoints and TLS settings supplied by the pool
operator.

`--cpu-max-threads-hint` is an approximate XMRig thread-selection hint,
not a hard CPU utilization limit. Actual CPU usage varies by processor,
thread count, and container limits.
