FROM alpine as build
ARG CURL_VERSION=curl-7_83_1
RUN apk add --no-cache ca-certificates libtool pkgconfig linux-headers git autoconf build-base automake

RUN mkdir /src

RUN cd /src && \
    git clone --recursive https://github.com/quictls/openssl /src/openssl && \
    cd /src/openssl && \
    ./Configure --prefix=/curllib/openssl && \
    make && \
    make install
    
RUN cd /src && \
    git clone --recursive https://github.com/ngtcp2/nghttp3 /src/nghttp3 && \
    cd /src/nghttp3 && \
    autoreconf -fi && \
    ./configure --enable-lib-only --prefix=/curllib/nghttp3 && \
    make && \
    make install
    
RUN cd /src && \
    git clone --recursive https://github.com/ngtcp2/ngtcp2 /src/ngtcp2 && \
    cd /src/ngtcp2 && \
    autoreconf -fi && \
    ./configure PKG_CONFIG_PATH=/curllib/openssl/lib64/pkgconfig:/curllib/nghttp3/lib/pkgconfig LDFLAGS="-Wl,-rpath,/curllib/openssl/lib64" --prefix=/curllib/ngtcp2 --enable-lib-only && \
    make && \
    make install

RUN cd /src && \
    git clone --recursive https://github.com/c-ares/c-ares && \
    cd /src/c-ares && \
    autoreconf -fi && \
    ./configure --prefix=/curllib/c-ares && \
    make && \
    make install

ARG LDFLAGS="-Wl,-rpath,/curllib/openssl/lib64"
RUN cd /src && \
    git clone --branch ${CURL_VERSION} --recursive https://github.com/curl/curl /src/curl && \
    cd /src/curl && \
    autoreconf -fi && \
    ./configure --with-openssl=/curllib/openssl --with-nghttp3=/curllib/nghttp3 --with-ngtcp2=/curllib/ngtcp2 --disable-shared --enable-static --enable-ares=/curllib/c-ares && \
    make && \
    make install
    
FROM alpine
COPY --from=build /usr/local/bin/curl /usr/local/bin/curl
COPY --from=build /lib/ld-musl-x86_64.so.1 /lib/ld-musl-x86_64.so.1
COPY --from=build /curllib/c-ares/lib/libcares.so.2 /curllib/c-ares/lib/libcares.so.2
COPY --from=build /curllib/nghttp3/lib/libnghttp3.so.2 /curllib/nghttp3/lib/libnghttp3.so.2
COPY --from=build /curllib/ngtcp2/lib/libngtcp2_crypto_openssl.so.2 /curllib/ngtcp2/lib/libngtcp2_crypto_openssl.so.2
COPY --from=build /curllib/ngtcp2/lib/libngtcp2.so.3 /curllib/ngtcp2/lib/libngtcp2.so.3
COPY --from=build /curllib/openssl/lib64/libssl.so.81.3 /curllib/openssl/lib64/libssl.so.81.3
COPY --from=build /curllib/openssl/lib64/libcrypto.so.81.3 /curllib/openssl/lib64/libcrypto.so.81.3
COPY --from=build /lib/ld-musl-x86_64.so.1 /lib/ld-musl-x86_64.so.1

RUN apk add --no-cache ca-certificates libtool pkgconfig linux-headers

ENTRYPOINT ["curl"]
CMD ["-V"]
