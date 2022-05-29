FROM debian:bullseye-slim
ENV DEBIAN_FRONTEND=noninteractive
RUN rm /etc/apt/sources.list && \
    echo "fs.file-max = 65535" > /etc/sysctl.conf && \
    echo "deb http://deb.debian.org/debian bullseye main contrib non-free" >> /etc/apt/sources.list && \
    echo "deb http://deb.debian.org/debian bullseye-updates main contrib non-free" >> /etc/apt/sources.list && \
    echo "deb http://ftp.debian.org/debian bullseye-backports main contrib non-free" >> /etc/apt/sources.list && \
    echo "deb http://security.debian.org/debian-security bullseye-security main contrib non-free" >> /etc/apt/sources.list && \
    apt update -y && \
    apt upgrade -y --allow-downgrades && \
    apt dist-upgrade -y --allow-downgrades && \
    apt autoremove --purge -y && \
    apt autoclean -y && \
    apt clean -y && \
    apt -o DPkg::Options::="--force-confnew" -y install git autoconf build-essential libtool pkg-config && \
    mkdir /src
    
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

ARG LDFLAGS="-Wl,-rpath,/curllib/openssl/lib64"
RUN cd /src && \
    git clone --recursive https://github.com/curl/curl /src/curl && \
    cd /src/curl && \
    autoreconf -fi && \
    ./configure --with-openssl=/curllib/openssl --with-nghttp3=/curllib/nghttp3 --with-ngtcp2=/curllib/ngtcp2 && \
    make && \
    make install
    
RUN rm -rf /src
    
ENTRYPOINT ["curl"]
CMD -V
