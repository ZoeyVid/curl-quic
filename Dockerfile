# syntax=docker/dockerfile:labs
FROM alpine:3.22.2 AS build
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]
ARG CURL_VERSION=curl-8_17_0
ARG WS_VERSION=v5.8.4-stable
ARG NGH3_VERSION=v1.13.1
ARG NGTCP2_VERSION=v1.18.0

RUN apk upgrade --no-cache -a && \
    apk add --no-cache ca-certificates git build-base autoconf automake coreutils libtool linux-headers \
                       nghttp2-dev nghttp2-static zlib-dev zlib-static && \
    \
    git clone --depth 1 https://github.com/wolfSSL/wolfssl --branch "$WS_VERSION" /src/wolfssl && \
    cd /src/wolfssl && \
    /src/wolfssl/autogen.sh && \
    # --enable-session-ticket --enable-earlydata --enable-psk --enable-harden --enable-altcertchains --enable-opensslextra
    /src/wolfssl/configure CFLAGS="-DWOLFSSL_NO_ASN_STRICT" --prefix=/usr/local --enable-curl --enable-quic --enable-ech --disable-shared --enable-static && \
    make -j "$(nproc)" && \
    make -j "$(nproc)" install && \
    \
    git clone --depth 1 --shallow-submodules --recurse-submodules https://github.com/ngtcp2/nghttp3 --branch "$NGH3_VERSION" /src/nghttp3 && \
    cd /src/nghttp3 && \
    autoreconf -fi && \
    /src/nghttp3/configure --prefix=/usr/local --enable-lib-only --disable-shared --enable-static && \
    make -j "$(nproc)" && \
    make -j "$(nproc)" install && \
    \
    git clone --depth 1 https://github.com/ngtcp2/ngtcp2 --branch "$NGTCP2_VERSION" /src/ngtcp2 && \
    cd /src/ngtcp2 && \
    autoreconf -fi && \
    /src/ngtcp2/configure --prefix=/usr/local --with-wolfssl --enable-lib-only --disable-shared --enable-static && \
    make -j "$(nproc)" && \
    make -j "$(nproc)" install && \
    \
    git clone --depth 1 https://github.com/curl/curl --branch "$CURL_VERSION" /src/curl && \
    cd /src/curl && \
    sed -i "s|-DEV||g" /src/curl/include/curl/curlver.h && \
    autoreconf -fi && \
    /src/curl/configure LDFLAGS="-static" PKG_CONFIG="pkg-config --static" --without-libpsl --with-wolfssl --with-nghttp2 --with-ngtcp2 --with-nghttp3 --enable-ech --enable-websockets --disable-shared --enable-static --disable-libcurl-option && \
    make -j "$(nproc)" LDFLAGS="-static -all-static" && \
    strip -s /src/curl/src/curl

FROM alpine:3.22.2
COPY --from=build /src/curl/src/curl /usr/local/bin/curl
RUN apk upgrade --no-cache -a && \
    apk add --no-cache ca-certificates tzdata tini && \
    curl -V && \
#    curl --compressed --http3-only -sIL https://quic.nginx.org && \
    mkdir -vp /host

WORKDIR /host
ENTRYPOINT ["tini", "--", "curl"]
CMD ["-V"]
