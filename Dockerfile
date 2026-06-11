# syntax=docker/dockerfile:labs
FROM alpine:3.24.0 AS build
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]
ARG CURL_VERSION=curl-8_20_0
ARG WS_VERSION=v5.9.1-stable
ARG NGH3_VERSION=v1.16.0
ARG NGTCP2_VERSION=v1.23.0

RUN apk upgrade --no-cache -a && \
    apk add --no-cache git clang lld compiler-rt llvm-libunwind-dev llvm-libunwind-static make autoconf automake libtool llvm file \
                       linux-headers nghttp2-dev nghttp2-static zlib-dev zlib-static

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
    # --enable-session-ticket --enable-earlydata --enable-psk --enable-harden --enable-altcertchains --enable-opensslextra
    /src/wolfssl/configure CFLAGS="$CFLAGS -DWOLFSSL_NO_ASN_STRICT" --prefix=/usr --enable-curl --enable-quic --enable-ech --disable-shared --enable-static && \
    make -j "$(nproc)" install 

RUN git clone --depth 1 --shallow-submodules --recurse-submodules https://github.com/ngtcp2/nghttp3 --branch "$NGH3_VERSION" /src/nghttp3 && \
    cd /src/nghttp3 && \
    autoreconf -fi && \
    /src/nghttp3/configure --prefix=/usr --enable-lib-only --disable-shared --enable-static && \
    make -j "$(nproc)" install

RUN git clone --depth 1 https://github.com/ngtcp2/ngtcp2 --branch "$NGTCP2_VERSION" /src/ngtcp2 && \
    cd /src/ngtcp2 && \
    autoreconf -fi && \
    /src/ngtcp2/configure --prefix=/usr --with-wolfssl --enable-lib-only --disable-shared --enable-static && \
    make -j "$(nproc)" install

RUN git clone --depth 1 https://github.com/curl/curl --branch "$CURL_VERSION" /src/curl && \
    cd /src/curl && \
    sed -i "s|-DEV||g" /src/curl/include/curl/curlver.h && \
    autoreconf -fi && \
    /src/curl/configure LDFLAGS="$LDFLAGS -static" PKG_CONFIG="pkg-config --static" --without-libpsl --with-wolfssl --with-nghttp2 --with-ngtcp2 --with-nghttp3 --enable-ech --enable-websockets --disable-shared --enable-static --disable-libcurl-option && \
    make -j "$(nproc)" LDFLAGS="$LDFLAGS -static-pie -all-static" && \
    llvm-strip -s /src/curl/src/curl && \
    file /src/curl/src/curl


FROM alpine:3.24.0
COPY --from=build /src/curl/src/curl /usr/local/bin/curl
RUN apk upgrade --no-cache -a && \
    apk add --no-cache ca-certificates tzdata tini && \
    curl -V && \
#    curl --compressed --http3-only -sIL https://quic.nginx.org && \
    mkdir -vp /host

WORKDIR /host
ENTRYPOINT ["tini", "--", "curl"]
CMD ["-V"]
