FROM ubuntu:24.04 AS builder
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    git cmake build-essential libuv1-dev libssl-dev ca-certificates \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /build
RUN git clone --depth 1 --branch v6.26.0 https://github.com/xmrig/xmrig.git
WORKDIR /build/xmrig
RUN cmake -B build -DWITH_HWLOC=OFF -DWITH_OPENCL=OFF -DWITH_CUDA=OFF \
    && cmake --build build -j"$(nproc)"

FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    libuv1 libssl3 ca-certificates tini \
    && rm -rf /var/lib/apt/lists/*
COPY --from=builder /build/xmrig/build/xmrig /usr/local/bin/xmrig
COPY start.sh /usr/local/bin/start-miner
RUN chmod 0755 /usr/local/bin/start-miner
WORKDIR /app
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/start-miner"]
