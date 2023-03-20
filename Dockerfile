FROM --platform="$BUILDPLATFORM" rust:1.68.0 as quiche-build
ARG QUICHE_VERSION=0.16.0 \
    TARGETARCH

RUN apt update && \
    apt install --yes git cmake && \
    git clone --recursive --branch "$QUICHE_VERSION" https://github.com/cloudflare/quiche /src/quiche && \
    cd /src/quiche && \
    if [ "$TARGETARCH" = "amd64" ]; then \
    apt install --yes crossbuild-essential-amd64 && \
    rustup target add x86_64-unknown-linux-musl && \
    TARGET_CC=x86_64-linux-gnu-gcc RUSTFLAGS="-C linker=x86_64-linux-gnu-gcc" CARGO_REGISTRIES_CRATES_IO_PROTOCOL=sparse cargo build --package quiche --release --features ffi,pkg-config-meta,qlog --target x86_64-unknown-linux-musl && \
    mkdir quiche/deps/boringssl/src/lib && \
    ln -vnf $(find target/x86_64-unknown-linux-musl/release -name libcrypto.a -o -name libssl.a) quiche/deps/boringssl/src/lib; \
    elif [ "$TARGETARCH" = "arm64" ]; then \
    apt install --yes crossbuild-essential-arm64 && \
    rustup target add aarch64-unknown-linux-musl && \
    TARGET_CC=aarch64-linux-gnu-gcc RUSTFLAGS="-C linker=aarch64-linux-gnu-gcc" CARGO_REGISTRIES_CRATES_IO_PROTOCOL=sparse cargo build --package quiche --release --features ffi,pkg-config-meta,qlog --target aarch64-unknown-linux-musl && \
    mkdir quiche/deps/boringssl/src/lib && \
    ln -vnf $(find target/aarch64-unknown-linux-musl/release -name libcrypto.a -o -name libssl.a) quiche/deps/boringssl/src/lib; \
    fi
    

FROM debian:testing-20230227-slim as curl-build
ARG CURL_VERSION=curl-8_0_1 \
    TARGETARCH

COPY --from=quiche-build /src/quiche /src/quiche
RUN apt update && \
    apt install --yes git build-essential autoconf automake libtool nghttp2-dev nghttp2-static && \
    git clone --recursive --branch "$CURL_VERSION" https://github.com/curl/curl /src/curl && \
    cd /src/curl && \
    autoreconf -fi && \
    if [ "$TARGETARCH" = "amd64" ]; then \
    ./configure LDFLAGS="-Wl,-rpath,/src/quiche/target/x86_64-unknown-linux-musl/release -static" PKG_CONFIG="pkg-config --static" --with-openssl=/src/quiche/quiche/deps/boringssl/src --with-quiche=/src/quiche/target/x86_64-unknown-linux-musl/release --with-nghttp2 --disable-shared --enable-static && \
    make -j "$(nproc)" LDFLAGS="-Wl,-rpath,/src/quiche/target/x86_64-unknown-linux-musl/release -L/src/quiche/quiche/deps/boringssl/src/lib -L/src/quiche/target/x86_64-unknown-linux-musl/release -static -all-static"; \
    elif [ "$TARGETARCH" = "arm64" ]; then \
    ./configure LDFLAGS="-Wl,-rpath,/src/quiche/target/aarch64-unknown-linux-musl/release -static" PKG_CONFIG="pkg-config --static" --with-openssl=/src/quiche/quiche/deps/boringssl/src --with-quiche=/src/quiche/target/aarch64-unknown-linux-musl/release --with-nghttp2 --disable-shared --enable-static && \
    make -j "$(nproc)" LDFLAGS="-Wl,-rpath,/src/quiche/target/aarch64-unknown-linux-musl/release -L/src/quiche/quiche/deps/boringssl/src/lib -L/src/quiche/target/aarch64-unknown-linux-musl/release -static -all-static"; \
    fi && \
    strip -s /src/curl/src/curl


FROM alpine:3.17.2
COPY --from=curl-build /src/curl/src/curl /usr/local/bin/curl
RUN curl --http3 -sIL https://cloudflare-quic.com && \
    mkdir -vp /host

WORKDIR /host
ENTRYPOINT ["curl"]
CMD ["-V"]
