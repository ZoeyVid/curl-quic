FROM alpine:3.17.2 as build

ARG QUICHE_VERSION=0.16.0
ARG NGHTTP2_VERSION=v1.51.0
ARG CURL_VERSION=curl-7_87_0

RUN apk upgrade --no-cache
RUN apk add --no-cache ca-certificates tzdata git build-base cmake autoconf automake pkgconfig libtool musl-dev nghttp2-dev nghttp2-static
RUN wget https://sh.rustup.rs -O - | sh -s -- -y

RUN mkdir /src

RUN cd /src && \
    git clone --recursive --branch ${QUICHE_VERSION} https://github.com/cloudflare/quiche /src/quiche && \
    cd /src/quiche && \
    source $HOME/.cargo/env && \
    cargo build --package quiche --release --features ffi,pkg-config-meta,qlog && \
    mkdir quiche/deps/boringssl/src/lib && \
    ln -vnf $(find target/release -name libcrypto.a -o -name libssl.a) quiche/deps/boringssl/src/lib

RUN cd /src && \
    git clone --recursive --branch ${CURL_VERSION} https://github.com/curl/curl /src/curl && \
    cd /src/curl && \
    autoreconf -fi && \
    ./configure LDFLAGS="-Wl,-rpath,/src/quiche/target/release -static" PKG_CONFIG="pkg-config --static" --with-openssl=/src/quiche/quiche/deps/boringssl/src --with-quiche=/src/quiche/target/release --with-nghttp2 --disable-shared --enable-static && \
    make -j "$(nproc)" LDFLAGS="-Wl,-rpath,/src/quiche/target/release -L/src/quiche/quiche/deps/boringssl/src/lib -L/src/quiche/target/release -static -all-static" && \
    strip -s /src/curl/src/curl

FROM alpine:3.17.2
COPY --from=build /src/curl/src/curl /usr/local/bin/curl

RUN apk upgrade --no-cache && \
    apk add --no-cache ca-certificates tzdata && \
    curl --http3 -sIL https://cloudflare-quic.com

ENTRYPOINT ["curl"]
CMD ["-V"]
