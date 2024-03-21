FROM alpine:3.19.1 as build

ARG CURL_VERSION=8.6.0
ARG WS_VERSION=v5.7.0-stable
ARG NGH3_VERSION=v1.2.0
ARG NGTCP2_VERSION=v1.4.0

RUN apk add --no-cache ca-certificates git build-base cmake autoconf automake coreutils libtool \
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
    mkdir /src/curl && \
    wget "https://curl.se/download/curl-$CURL_VERSION.tar.gz" -O - | tar xz -C /src/curl --strip-components=1 && \
    cd /src/curl && \
    autoreconf -fi && \
    /src/curl/configure LDFLAGS="-static" PKG_CONFIG="pkg-config --static" --without-libpsl --with-wolfssl --with-nghttp2 --with-ngtcp2 --with-nghttp3 --disable-ech --enable-websockets --disable-shared --enable-static --disable-libcurl-option && \
    make -j "$(nproc)" LDFLAGS="-static -all-static" && \
    strip -s /src/curl/src/curl

FROM alpine:3.19.1
COPY --from=build /src/curl/src/curl /usr/local/bin/curl
RUN apk add --no-cache ca-certificates tzdata && \
    curl -V && \
    curl --compressed --http3-only -sIL https://quic.nginx.org && \
    mkdir -vp /host

WORKDIR /host
ENTRYPOINT ["curl"]
CMD ["-V"]
