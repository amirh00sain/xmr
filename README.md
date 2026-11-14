# XMRig on Ubuntu with Docker

## Requirements
- Ubuntu with Docker Engine installed and working (`docker info` succeeds).
- Your own Monero wallet receiving address.
- Enough available RAM for RandomX. XMRig commonly needs roughly 2.3 GB for its dataset plus overhead; allow at least 4 GB available to the container/host.

## Install and run
1. Extract this folder.
2. Run `cp .env.example .env` if `.env` does not exist.
3. Edit `.env` and replace `WALLET` with your own receiving address.
4. Run:
   ```bash
   chmod +x install-and-run.sh
   ./install-and-run.sh
   ```
   First run creates `.env` and exits so you can edit it. Run it again after editing.

## Monitor
```bash
docker logs -f --tail 100 xmr-miner
```
XMRig should print `speed 10s/60s/15m` periodically because `--print-time=10` is enabled. Look for `accepted` to confirm accepted shares.

## Stop / restart
```bash
docker stop xmr-miner
docker start xmr-miner
```

## Important
- `CPU_HINT` is an approximate XMRig thread-selection hint, not a guaranteed CPU percentage limit. Change it in `.env`, then recreate the container by running `./install-and-run.sh`.
- The configuration intentionally runs one stable pool and does not restart the miner every few minutes. This avoids repeatedly rebuilding the RandomX dataset.
- No random background ping process is included; it does not help mining performance or pool connectivity.
- `MSR kernel module is not available` and `HUGE PAGES 0%` are optimization notices, not by themselves proof that mining failed.
- The sample pool endpoint is the endpoint seen receiving a job in the log you supplied. Pool operators can change endpoints/ports/TLS settings; check their official instructions if it stops connecting.


## Legacy environment variables
The `.env.example` also retains the old `MIN_CPU`, `MAX_CPU`, ping interval,
pool-list, and pool-check variables as **deprecated examples only**. The
current `start.sh` ignores those legacy variables. It uses only `WALLET`,
`POOL`, `TLS`, `PASSWORD`, `CPU_HINT`, and `DONATE_LEVEL`. The old pool
hostnames and ports are not guaranteed to remain valid. The previously
provided wallet address is not copied into the package; enter your own
receiving address in `.env`.
