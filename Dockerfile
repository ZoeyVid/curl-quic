FROM --platform=${BUILDPLATFORM} alpine:3.16.2 as build

ARG QUICHE_VERSION=0.16.0
ARG NGHTTP2_VERSION=v1.50.0
ARG CURL_VERSION=curl-7_86_0

RUN apk add --no-cache ca-certificates git pkgconfig libtool make cmake autoconf automake musl-dev gcc g++
RUN wget -q -O - https://sh.rustup.rs | sh -s -- -y

RUN mkdir /src

RUN cd /src && \
#    git clone --recursive https://github.com/cloudflare/quiche /src/quiche && \
    git clone --recursive --branch ${QUICHE_VERSION} https://github.com/cloudflare/quiche /src/quiche && \
    cd /src/quiche && \
    source $HOME/.cargo/env && \
    cargo build --package quiche --release --features ffi,pkg-config-meta,qlog && \
    mkdir quiche/deps/boringssl/src/lib && \
    ln -vnf $(find target/release -name libcrypto.a -o -name libssl.a) quiche/deps/boringssl/src/lib

RUN cd /src && \
    git clone --recursive --branch ${NGHTTP2_VERSION} https://github.com/nghttp2/nghttp2 /src/nghttp2 && \
    cd /src/nghttp2 && \
    autoreconf -fi && \
    ./configure && \
    make -j "$(nproc)" && \
    make -j "$(nproc)" install

RUN cd /src && \
    git clone --recursive --branch ${CURL_VERSION} https://github.com/curl/curl /src/curl && \
    cd /src/curl && \
    autoreconf -fi && \
    ./configure LDFLAGS="-Wl,-rpath,/src/quiche/target/release" --with-openssl=/src/quiche/quiche/deps/boringssl/src --with-quiche=/src/quiche/target/release --with-nghttp2 --disable-shared --enable-static && \
    make -j "$(nproc)" && \
    make -j "$(nproc)" install

FROM --platform=${BUILDPLATFORM} busybox:1.35.0
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

COPY --from=build /usr/local/bin/curl /usr/local/bin/curl
COPY --from=build /usr/lib/libgcc_s.so.1 /usr/lib/libgcc_s.so.1
COPY --from=build /lib/ld-musl-x86_64.so.1 /lib/ld-musl-x86_64.so.1
COPY --from=build /usr/local/lib/libnghttp2.so.14 /usr/local/lib/libnghttp2.so.14

LABEL org.opencontainers.image.source="https://github.com/SanCraftDev/curl-quic"
ENTRYPOINT ["curl"]
CMD ["-V"]
