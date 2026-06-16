# syntax=docker/dockerfile:1.24.0@sha256:87999aa3d42bdc6bea60565083ee17e86d1f3339802f543c0d03998580f9cb89
FROM alpine:3.24.1@sha256:bec4ccd3817e7c824eb0388971a0b83fab111d586285511ba0266b77e8dc65a9 AS build
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]
ARG CURL_VERSION=curl-8_20_0
ARG WS_VERSION=v5.9.1-stable
ARG NGH3_VERSION=v1.16.0
ARG NGTCP2_VERSION=v1.23.0
ARG BROTLI_VERSION=v1.2.0

RUN apk upgrade --no-cache -a && \
    apk add --no-cache git clang lld compiler-rt llvm-libunwind-dev llvm-libunwind-static cmake ninja autoconf automake make libtool llvm file \
                       linux-headers nghttp2-dev nghttp2-static zlib-dev zlib-static zstd-dev zstd-static perl

RUN for f in $(apk info --no-cache -qL libgcc-static libstdc++-dev); do rm /"$f"; done && \
    echo "-fuse-ld=lld --rtlib=compiler-rt --unwindlib=libunwind -stdlib=libc++" | tee /etc/clang*/*.cfg

ARG FLAGS
ARG CC=clang
ARG LD=ld.lld
ARG AR=llvm-ar

ARG FLAGS
ARG CFLAGS="$FLAGS -m64 -O3 -pipe -flto=full -ffunction-sections -fdata-sections -fno-math-errno -ffp-contract=fast -fstack-clash-protection -fstack-protector-strong -fzero-call-used-regs=used-gpr -fstrict-flex-arrays=3 -ftrivial-auto-var-init=zero -fno-delete-null-pointer-checks -fno-strict-overflow -fno-strict-aliasing -fno-semantic-interposition -fno-plt -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=3 -Wformat=2 -Werror=format-security -Wno-sign-compare"
ARG LDFLAGS="-m64 -Wl,-s -Wl,-O2 -Wl,--lto-O3 -Wl,--icf=safe -Wl,--gc-sections -Wl,-z,noexecstack -Wl,-z,relro -Wl,-z,now -Wl,--sort-common -Wl,--as-needed -Wl,-z,pack-relative-relocs -Wl,--no-copy-dt-needed-entries"

RUN git config --global advice.detachedHead false && \
    git config --global init.defaultBranch main

RUN git clone --depth 1 https://github.com/wolfSSL/wolfssl --branch "$WS_VERSION" /src/wolfssl && \
    cd /src/wolfssl && \
    /src/wolfssl/autogen.sh && \
    /src/wolfssl/configure CFLAGS="$CFLAGS -DWOLFSSL_NO_ASN_STRICT" --prefix=/usr --enable-all --enable-static --disable-shared --disable-crypttests --disable-examples && \
    make -j "$(nproc)" install 

RUN git clone --depth 1 --shallow-submodules --recurse-submodules https://github.com/ngtcp2/nghttp3 --branch "$NGH3_VERSION" /src/nghttp3 && \
    cd /src/nghttp3 && \
    autoreconf -fi && \
    /src/nghttp3/configure --prefix=/usr --enable-lib-only --enable-static --disable-shared && \
    make -j "$(nproc)" install

RUN git clone --depth 1 https://github.com/ngtcp2/ngtcp2 --branch "$NGTCP2_VERSION" /src/ngtcp2 && \
    cd /src/ngtcp2 && \
    autoreconf -fi && \
    /src/ngtcp2/configure --prefix=/usr --with-wolfssl --enable-lib-only --enable-static --disable-shared && \
    make -j "$(nproc)" install

RUN git clone --depth 1 https://github.com/google/brotli --branch "$BROTLI_VERSION" /src/brotli && \
    cd /src/brotli && \
    cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -S . -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_SHARED_LIBS=OFF && \
    ninja install

RUN git clone --depth 1 https://github.com/curl/curl --branch "$CURL_VERSION" /src/curl && \
    cd /src/curl && \
    wget -q https://github.com/curl/curl/commit/50ffc359e943b2b55268b6c8507524fb0c23dc9c.patch -O /src/curl/1.patch && \
    echo "3da404dada238850f37e3aa4cbb917441004aa080628fba66c982f1f777e6beb  /src/curl/1.patch" | sha256sum -c - && \
    git apply /src/curl/1.patch && \
    sed -i "s|-DEV||g" /src/curl/include/curl/curlver.h && \
    autoreconf -fi && \
    /src/curl/configure LDFLAGS="$LDFLAGS -static" PKG_CONFIG="pkg-config --static" --without-libpsl --with-wolfssl --with-nghttp2 --with-ngtcp2 --with-nghttp3 --with-zlib --with-brotli --with-zstd --enable-httpsrr --enable-ech --enable-ntlm --enable-unity --enable-static --disable-shared --disable-docs && \
    make -j "$(nproc)" LDFLAGS="$LDFLAGS -static-pie -all-static" && \
    llvm-strip -s /src/curl/src/curl && \
    ls -lh /src/curl/src/curl && \
    file /src/curl/src/curl


FROM alpine:3.24.1@sha256:bec4ccd3817e7c824eb0388971a0b83fab111d586285511ba0266b77e8dc65a9
COPY --from=build /src/curl/src/curl /usr/local/bin/curl
RUN apk upgrade --no-cache -a && \
    apk add --no-cache ca-certificates tzdata tini && \
    curl -V && \
#    curl --compressed --http3-only -sIL https://quic.nginx.org && \
    mkdir -vp /host

WORKDIR /host
ENTRYPOINT ["tini", "--", "curl"]
CMD ["-V"]
