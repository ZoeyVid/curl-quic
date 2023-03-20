FROM --platform="$BUILDPLATFORM" rust:1.68.0 as quiche-build
ARG QUICHE_VERSION=0.16.0 \
    TARGETARCH

RUN apt update && \
    apt install --yes git cmake && \
    git clone --recursive --branch "$QUICHE_VERSION" https://github.com/cloudflare/quiche /src && \
    cd /src && \
    if [ "$TARGETARCH" = "amd64" ]; then \
    apt install --yes crossbuild-essential-amd64 && \
    rustup target add x86_64-unknown-linux-gnu && \
    RUSTFLAGS += -C linker=x86_64-linux-gnu-gcc && \
    TARGET_CC=x86_64-linux-gnu-gcc CARGO_REGISTRIES_CRATES_IO_PROTOCOL=sparse cargo build --package quiche --release --features ffi,pkg-config-meta,qlog --target x86_64-unknown-linux-gnu; \
    elif [ "$TARGETARCH" = "arm64" ]; then \
    apt install --yes crossbuild-essential-arm64 && \
    rustup target add aarch64-unknown-linux-gnu && \
    RUSTFLAGS += -C linker=aarch64-linux-gnu-gcc && \
    TARGET_CC=aarch64-linux-gnu-gcc CARGO_REGISTRIES_CRATES_IO_PROTOCOL=sparse cargo build --package quiche --release --features ffi,pkg-config-meta,qlog --target aarch64-unknown-linux-gnu; \
    fi && \
    mkdir quiche/deps/boringssl/src/lib && \
    ln -vnf $(find target -name libcrypto.a -o -name libssl.a) quiche/deps/boringssl/src/lib
    

FROM alpine:3.17.2 as curl-build
ARG CURL_VERSION=curl-8_0_1

COPY --from=quiche-build /src /src/quiche
RUN apk add --no-cache git build-base autoconf automake nghttp2-dev nghttp2-static && \
    git clone --recursive --branch "$CURL_VERSION" https://github.com/curl/curl /src/curl && \
    cd /src/curl && \
    autoreconf -fi && \
    ./configure LDFLAGS="-Wl,-rpath,/src/quiche/target/release -static" PKG_CONFIG="pkg-config --static" --with-openssl=/src/quiche/quiche/deps/boringssl/src --with-quiche=/src/quiche/target/release --with-nghttp2 --disable-shared --enable-static && \
    make -j "$(nproc)" LDFLAGS="-Wl,-rpath,/src/quiche/target/release -L/src/quiche/quiche/deps/boringssl/src/lib -L/src/quiche/target/release -static -all-static" && \
    strip -s /src/curl/src/curl


FROM alpine:3.17.2
COPY --from=curl-build /src/curl/src/curl /usr/local/bin/curl
RUN curl --http3 -sIL https://cloudflare-quic.com && \
    mkdir -vp /host

WORKDIR /host
ENTRYPOINT ["curl"]
CMD ["-V"]
