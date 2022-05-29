FROM alpine
ARG LDFLAGS="-Wl,-rpath,/curllib/openssl/lib64" ./configure --with-openssl=/curllib/openssl --with-nghttp3=/curllib/nghttp3 --with-ngtcp2=/curllib/ngtcp2
RUN apk add --no-cache git autoconf && \
    mkdir /src && \
    
    cd /src && \
    git clone --recursive https://github.com/quictls/openssl /src/openssl && \
    cd /src/openssl && \
    ./Configure --prefix=/curllib/openssl && \
    make && \
    make install && \
    
    cd /src && \
    git clone --recursive https://github.com/ngtcp2/nghttp3 /src/nghttp3 && \
    cd /src/nghttp3 && \
    ./configure --enable-lib-only --prefix=/curllib/nghttp3 && \
    make && \
    make install && \
    
    cd /src && \
    git clone --recursive https://github.com/ngtcp2/ngtcp2 /src/ngtcp2 && \
    cd /src/ngtcp2 && \
    autoreconf -fi && \
    ./configure PKG_CONFIG_PATH=/curllib/openssl/lib64/pkgconfig:/curllib/nghttp3/lib64/pkgconfig LDFLAGS="-Wl,-rpath,/curllib/openssl/lib64" --prefix=/curllib/ngtcp2 --enable-lib-only && \
    make && \
    make install && \
    
    cd /src && \
    git clone --recursive https://github.com/curl/curl /src/curl && \
    cd /src/curl && \
    autoreconf -fi && \
    make && \
    make install && \
    
    rm -rf /src
    
CMD curl
