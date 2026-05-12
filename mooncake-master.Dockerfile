# syntax=docker/dockerfile:1.7

ARG UBUNTU_VERSION=22.04

FROM ubuntu:${UBUNTU_VERSION} AS builder

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1

ARG CMAKE_BUILD_TYPE=Release
ARG BUILD_JOBS=2

ENV PATH="/usr/local/go/bin:${PATH}"

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        python3 \
        python3-dev \
        python3-pip \
        python-is-python3 \
        pkg-config \
        ninja-build && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
COPY . /workspace

RUN bash dependencies.sh -y

RUN export GOPROXY=https://goproxy.cn,direct

RUN cmake -S . -B build -G Ninja \
        -DBUILD_UNIT_TESTS=OFF \
        -DWITH_TE=ON \
        -DWITH_STORE=ON \
        -DWITH_STORE_RUST=OFF \
        -DWITH_EP=OFF \
        -DUSE_CUDA=OFF \
        -DUSE_HTTP=ON \
        -DUSE_ETCD=ON \
        -DSTORE_USE_ETCD=ON \
        -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE} && \
    cmake --build build --target mooncake_master -j${BUILD_JOBS}

FROM ubuntu:${UBUNTU_VERSION} AS runtime

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        ibverbs-providers \
        rdma-core \
        libibverbs1 \
        librdmacm1 \
        libnuma1 \
        liburing2 \
        libyaml-0-2 \
        libcurl4 \
        libgflags2.2 \
        libgoogle-glog0v5 \
        libjsoncpp25 \
        libunwind8 \
        zlib1g \
        libzstd1 && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /workspace/build/mooncake-store/src/mooncake_master /usr/local/bin/mooncake_master
COPY --from=builder /workspace/build/mooncake-asio/libasio.so /usr/local/lib/libasio.so

ENV LD_LIBRARY_PATH=/usr/local/lib

EXPOSE 50051 8080 9003

ENTRYPOINT ["mooncake_master"]
