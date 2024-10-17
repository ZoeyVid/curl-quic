# syntax=docker/dockerfile:labs
FROM alpine:3.20.3 AS build
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]
ARG CURL_VERSION=curl-8_10_1
ARG WS_VERSION=v5.7.2-stable
ARG NGH3_VERSION=v1.6.0
ARG NGTCP2_VERSION=v1.8.1

RUN apk upgrade --no-cache -a && \
    apk add --no-cache ca-certificates git build-base cmake autoconf automake coreutils libtool \
                       nghttp2-dev nghttp2-static zlib-dev zlib-static && \
    \
    git clone --recursive --branch "$WS_VERSION" https://github.com/wolfSSL/wolfssl /src/wolfssl && \
    cd /src/wolfssl && \
    /src/wolfssl/autogen.sh && \
    /src/wolfssl/configure --prefix=/usr --enable-curl --disable-oldtls --enable-quic --enable-ech --enable-psk --enable-session-ticket --enable-earlydata --disable-shared --enable-static && \
    make -j "$(nproc)" && \
    make -j "$(nproc)" install && \
    \
    git clone --recursive --branch "$NGH3_VERSION" https://github.com/ngtcp2/nghttp3 /src/nghttp3 && \
    cd /src/nghttp3 && \
    autoreconf -fi && \
    /src/nghttp3/configure --prefix=/usr --enable-lib-only --disable-shared --enable-static && \
    make -j "$(nproc)" && \
    make -j "$(nproc)" install && \
    \
    git clone --recursive --branch "$NGTCP2_VERSION" https://github.com/ngtcp2/ngtcp2 /src/ngtcp2 && \
    cd /src/ngtcp2 && \
    autoreconf -fi && \
    /src/ngtcp2/configure --prefix=/usr --with-wolfssl --enable-lib-only --disable-shared --enable-static && \
    make -j "$(nproc)" && \
    make -j "$(nproc)" install && \
    \
    git clone --recursive --branch "$CURL_VERSION" https://github.com/curl/curl /src/curl && \
    cd /src/curl && \
    autoreconf -fi && \
    /src/curl/configure LDFLAGS="-static" PKG_CONFIG="pkg-config --static" --without-libpsl --with-wolfssl --with-nghttp2 --with-ngtcp2 --with-nghttp3 --disable-ech --enable-websockets --disable-shared --enable-static --disable-libcurl-option && \
    make -j "$(nproc)" LDFLAGS="-static -all-static" && \
    strip -s /src/curl/src/curl

FROM alpine:3.20.3
COPY --from=build /src/curl/src/curl /usr/local/bin/curl
RUN apk upgrade --no-cache -a && \
    apk add --no-cache ca-certificates tzdata tini && \
    curl -V && \
    curl --compressed --http3-only -sIL https://quic.nginx.org && \
    mkdir -vp /host

WORKDIR /host
ENTRYPOINT ["tini", "--", "curl"]
CMD ["-V"]
