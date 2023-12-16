FROM rust:1.74.1-alpine3.18 as build

ARG QUICHE_VERSION=0.20.0
ARG CURL_VERSION=curl-8_5_0

ARG CARGO_REGISTRIES_CRATES_IO_PROTOCOL=sparse

RUN sed -i "s|v3.18|v3.19|g" /etc/apk/repositories && \
    apk add --no-cache --upgrade apk-tools && \
    apk upgrade --available && \
    sync

WORKDIR /src
RUN apk add --no-cache ca-certificates git build-base cmake autoconf nghttp2-dev nghttp2-static ngtcp2-dev nghttp3-dev zlib-dev zlib-static zstd-dev zstd-static brotli-dev brotli-static && \
    git clone --recursive --branch "$CURL_VERSION" https://github.com/curl/curl /src && \
    autoreconf -fi && \
    ./configure --with-wolfssl --with-nghttp2 --with-ngtcp2 --with-nghttp3 --enable-ech --enable-websockets --disable-shared --enable-static --disable-libcurl-option && \
    make -j "$(nproc)" && \
    strip -s /src/src/curl

FROM alpine:3.19.0
COPY --from=build /src/src/curl /usr/local/bin/curl
RUN apk add --no-cache ca-certificates tzdata && \
    curl --compressed --http3-only -sIL https://quic.nginx.org && \
    mkdir -vp /host

WORKDIR /host
ENTRYPOINT ["curl"]
CMD ["-V"]
