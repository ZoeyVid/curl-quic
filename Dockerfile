FROM alpine:3.19.0 as build

ARG CURL_VERSION=curl-8_5_0
ARG OS_VERSION=openssl-3.1.4+quic

RUN apk add --no-cache ca-certificates git build-base cmake autoconf automake libtool nghttp2-dev nghttp2-static ngtcp2-dev nghttp3-dev zlib-dev zlib-static zstd-dev zstd-static brotli-dev brotli-static && \
    \
    git clone --recursive --branch "$OS_VERSION" https://github.com/quictls/openssl /src/openssl && \
    cd /src/openssl && \
    /src/openssl/Configure --prefix=/usr && \
    make && \
    make install && \
    
    \
    git clone --recursive --branch "$CURL_VERSION" https://github.com/curl/curl /src/curl && \
    cd /src/curl && \
    autoreconf -fi && \
    /src/curl/configure --with-openssl --with-nghttp2 --with-ngtcp2 --with-nghttp3 --disable-ech --enable-websockets --disable-shared --enable-static --disable-libcurl-option && \
    make -j "$(nproc)" && \
    strip -s /src/curl/src/curl

FROM alpine:3.19.0
COPY --from=build /src/curl/src/curl /usr/local/bin/curl
RUN apk add --no-cache ca-certificates tzdata && \
    curl --compressed --http3-only -sIL https://quic.nginx.org && \
    mkdir -vp /host

WORKDIR /host
ENTRYPOINT ["curl"]
CMD ["-V"]
