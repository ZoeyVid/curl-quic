# syntax=docker/dockerfile:1.26.0@sha256:ecfaec9ed6d810b56388c508f4121597bfbba70d41a6dfeee4d8cad5f295fc32
FROM alpine:3.24.1@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b AS build
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

ARG AWSLC_VERSION=991e67ff4cf04df4dd89e407f8b920c6936cb56a # v5.5.0
ARG NGTCP2_VERSION=843aa72100b508e192f119439a943028b0c6f030 # v1.25.0
ARG NGHTTP3_VERSION=868e81b343d1350597b47f78a5958d60c3695aa4 # v1.18.0
ARG NGHTTP2_VERSION=b69da4c2656bb66311c2a84bb2f4a3a1da2da393 # v1.70.0
ARG ZSTD_VERSION=ac66b19e6bd6b83238bf008eecc1298105298532 # v1.5.7
ARG BROTLI_VERSION=028fb5a23661f123017c060daa546b55cf4bde29 # v1.2.0
ARG ZLIBNG_VERSION=12731092979c6d07f42da27da673a9f6c7b13586 # 2.3.3
ARG CARES_VERSION=63a4c4c71b86e448bcc1c55287c35aa4aa0f4246 # v1.34.8
ARG CURL_VERSION=3f00a2f6fa97f7721b65606954aac979dcb6caac # curl-8_21_0

COPY git-clone-commit.sh /usr/local/bin

RUN apk upgrade --no-cache -a && \
    apk add --no-cache git clang lld compiler-rt llvm-libunwind-static libc++-dev cmake ninja pkgconf llvm file perl

RUN for f in $(apk info --no-cache -qL libgcc-static libstdc++-dev); do rm /"$f"; done && \
    echo "-fuse-ld=lld --rtlib=compiler-rt --unwindlib=libunwind -stdlib=libc++ -D_LIBCPP_HARDENING_MODE=_LIBCPP_HARDENING_MODE_EXTENSIVE" | tee /etc/clang*/*.cfg

ARG CC=clang
ARG CXX=clang++
ARG LD=ld.lld
ARG AR=llvm-ar

ARG FLAGS
ARG CFLAGS="$FLAGS -m64 -O3 -pipe -flto=full -ffunction-sections -fdata-sections -fno-math-errno -ffp-contract=fast -fstack-clash-protection -fstack-protector-strong -fzero-call-used-regs=used-gpr -fstrict-flex-arrays=3 -ftrivial-auto-var-init=zero -fno-delete-null-pointer-checks -fno-strict-overflow -fno-strict-aliasing -fno-semantic-interposition -fno-plt -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=3 -Wformat=2 -Werror=format-security -DBN_FLG_CONSTTIME=0"
ARG CXXFLAGS="$CFLAGS"
ARG LDFLAGS="-m64 -Wl,-s -Wl,-O2 -Wl,--lto-O3 -Wl,--icf=safe -Wl,--gc-sections -Wl,-z,noexecstack -Wl,-z,relro -Wl,-z,now -Wl,--sort-common -Wl,--as-needed -Wl,-z,pack-relative-relocs -Wl,--no-copy-dt-needed-entries"

RUN git config --global advice.detachedHead false && \
    git config --global init.defaultBranch main

RUN git-clone-commit.sh https://github.com/aws/aws-lc "$AWSLC_VERSION" /src/aws-lc && \
    cd /src/aws-lc && \
    cmake /src/aws-lc -G Ninja -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DDISABLE_GO=ON -DDISABLE_PERL=ON -DBUILD_TOOL=OFF -DBUILD_TESTING=OFF && \
    ninja install

ARG BORINGSSL_LIBS="-lssl -lcrypto"
RUN git-clone-commit.sh https://github.com/ngtcp2/ngtcp2 "$NGTCP2_VERSION" /src/ngtcp2 && \
    cd /src/ngtcp2 && \
    cmake /src/ngtcp2 -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_SHARED_LIBS=OFF -DENABLE_SHARED_LIB=OFF -DENABLE_LIB_ONLY=ON -DENABLE_OPENSSL=OFF -DENABLE_BORINGSSL=ON -DBUILD_TESTING=OFF && \
    ninja install

RUN git-clone-commit.sh https://github.com/ngtcp2/nghttp3 "$NGHTTP3_VERSION" /src/nghttp3 true && \
    cd /src/nghttp3 && \
    cmake /src/nghttp3 -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_SHARED_LIBS=OFF -DENABLE_SHARED_LIB=OFF -DENABLE_LIB_ONLY=ON -DBUILD_TESTING=OFF && \
    ninja install

RUN git-clone-commit.sh https://github.com/nghttp2/nghttp2 "$NGHTTP2_VERSION" /src/nghttp2 && \
    cd /src/nghttp2 && \
    cmake /src/nghttp2 -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_SHARED_LIBS=OFF -DBUILD_STATIC_LIBS=ON -DENABLE_LIB_ONLY=ON -DENABLE_FAILMALLOC=OFF -DBUILD_TESTING=OFF -DENABLE_DOC=OFF && \
    ninja install

RUN git-clone-commit.sh https://github.com/facebook/zstd "$ZSTD_VERSION" /src/zstd && \
    cd /src/zstd && \
    cmake /src/zstd/build/cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_SHARED_LIBS=OFF -DZSTD_BUILD_SHARED=OFF -DZSTD_BUILD_PROGRAMS=OFF && \
    ninja install

RUN git-clone-commit.sh https://github.com/google/brotli "$BROTLI_VERSION" /src/brotli && \
    cd /src/brotli && \
    cmake /src/brotli -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_SHARED_LIBS=OFF -DBROTLI_BUILD_TOOLS=OFF && \
    ninja install

RUN git-clone-commit.sh https://github.com/zlib-ng/zlib-ng "$ZLIBNG_VERSION" /src/zlibng && \
    cd /src/zlibng && \
    cmake /src/zlibng -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_SHARED_LIBS=OFF -DZLIB_COMPAT=ON -DBUILD_TESTING=OFF && \
    ninja install

RUN git-clone-commit.sh https://github.com/c-ares/c-ares "$CARES_VERSION" /src/cares && \
    cd /src/cares && \
    cmake /src/cares -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_SHARED_LIBS=OFF -DCARES_SHARED=OFF -DCARES_STATIC=ON -DCARES_BUILD_TOOLS=OFF && \
    ninja install

ARG LDFLAGS="$LDFLAGS -static-pie"
RUN git-clone-commit.sh https://github.com/curl/curl "$CURL_VERSION" /src/curl && \
    cd /src/curl && \
    sed -i "s|-DEV||g" /src/curl/include/curl/curlver.h && \
    cmake /src/curl -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_LIBCURL_DOCS=OFF \
        -DBUILD_MISC_DOCS=OFF \
        -DBUILD_EXAMPLES=OFF \
        -DBUILD_TESTING=OFF \
        -DCURL_DROP_UNUSED=TRUE \
        -DCURL_LTO=TRUE \
        -DCURL_CA_EMBED=/etc/ssl/certs/ca-certificates.crt \
        -DUSE_ECH=ON \
        -DUSE_HTTPSRR=ON \
        -DUSE_PROXY_HTTP3=ON \
        -DUSE_SSLS_EXPORT=ON \
        -DCMAKE_UNITY_BUILD=ON \
        -DCURL_BROTLI=ON \
        -DCURL_USE_CMAKECONFIG=ON \
        -DCURL_USE_LIBPSL=OFF \
        -DCURL_ZLIB=ON \
        -DCURL_ZSTD=ON \
        -DENABLE_ARES=ON \
        -DUSE_NGTCP2=ON && \
    ninja && \
    llvm-strip -s /src/curl/src/curl && \
    ls -lh /src/curl/src/curl && \
    file /src/curl/src/curl && \
    /src/curl/src/curl -V


FROM scratch
COPY --from=build /src/curl/src/curl /usr/local/bin/curl
WORKDIR /host
ENTRYPOINT ["curl"]
