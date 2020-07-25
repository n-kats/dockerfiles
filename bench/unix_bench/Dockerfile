FROM ubuntu:18.04

RUN set -x \
  && apt-get update \
  && apt-get install -y \
    build-essential \
    curl \
    tar \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /build
RUN curl -s https://storage.googleapis.com/google-code-archive-downloads/v2/code.google.com/byte-unixbench/UnixBench5.1.3.tgz \
  | tar zx -C /build \
  && mv UnixBench /work \
  && rm -r /build

WORKDIR /work
