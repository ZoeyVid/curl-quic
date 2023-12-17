FROM alpine:3.19.0 as build

ARG CURL_VERSION=curl-8_5_0
ARG WS_VERSION=v5.6.4-stable

RUN apk add --no-cache ca-certificates git build-base cmake autoconf automake coreutils libtool \
                       nghttp2-dev nghttp2-static zlib-dev zlib-static zstd-dev zstd-static brotli-dev brotli-static libssh2-dev libssh2-static && \
    \
    git clone --recursive --branch "$WS_VERSION" https://github.com/wolfSSL/wolfssl /src/wolfssl && \
    cd /src/wolfssl && \
    /src/wolfssl/autogen.sh && \
    /src/wolfssl/configure --prefix=/usr --enable-curl --disable-oldtls --enable-quic --enable-ech --disable-shared --enable-psk --enable-session-ticket --enable-earlydata --enable-static && \
    make && \
    make install && \
    \
    git clone --recursive https://github.com/ngtcp2/nghttp3 /src/nghttp3 && \
    cd /src/nghttp3 && \
    autoreconf -fi && \
    /src/nghttp3/configure --prefix=/usr --enable-lib-only --disable-shared --enable-static && \
    make && \
    make install && \
    \
    git clone --recursive https://github.com/ngtcp2/ngtcp2 /src/ngtcp2 && \
    cd /src/ngtcp2 && \
    autoreconf -fi && \
    /src/ngtcp2/configure --prefix=/usr --with-wolfssl --enable-lib-only --disable-shared --enable-static && \
    make && \
    make install && \
    \
    git clone --recursive --branch "$CURL_VERSION" https://github.com/curl/curl /src/curl && \
    cd /src/curl && \
    autoreconf -fi && \
    /src/curl/configure LDFLAGS="-static" PKG_CONFIG="pkg-config --static" --with-wolfssl --with-nghttp2 --with-ngtcp2 --with-nghttp3 --disable-ech --enable-websockets --disable-shared --enable-static --disable-libcurl-option && \
    make -j "$(nproc)" LDFLAGS="-static -all-static" && \
    strip -s /src/curl/src/curl

FROM alpine:3.19.0
COPY --from=build /src/curl/src/curl /usr/local/bin/curl
RUN apk add --no-cache ca-certificates tzdata && \
    curl --compressed --http3-only -sIL https://quic.nginx.org && \
    mkdir -vp /host

WORKDIR /host
ENTRYPOINT ["curl"]
CMD ["-V"]
