FROM alpine:20221110 as build

ARG QUICHE_VERSION=0.16.0
ARG NGHTTP2_VERSION=v1.51.0
ARG CURL_VERSION=curl-7_86_0

RUN apk upgrade --no-cache
RUN apk add --no-cache ca-certificates wget tzdata git make cmake gcc g++ autoconf automake pkgconfig libtool musl-dev
RUN wget -q -O - https://sh.rustup.rs | sh -s -- -y

RUN mkdir /src

RUN cd /src && \
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

FROM alpine:20221110
RUN apk upgrade --no-cache
RUN apk add --no-cache ca-certificates wget tzdata libgcc

COPY --from=build /usr/local/bin/curl /usr/local/bin/curl
COPY --from=build /usr/local/lib/libnghttp2.so.14 /usr/local/lib/libnghttp2.so.14

RUN curl --http3 -sIL https://cloudflare-quic.com

LABEL org.opencontainers.image.source="https://github.com/SanCraftDev/curl-quic"
ENTRYPOINT ["curl"]
CMD ["-V"]
