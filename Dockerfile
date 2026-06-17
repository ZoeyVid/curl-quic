# syntax=docker/dockerfile:1.24.0@sha256:87999aa3d42bdc6bea60565083ee17e86d1f3339802f543c0d03998580f9cb89
FROM alpine:3.24.1@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b AS build
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

ARG AWSLC_VERSION=6f246af4cd1de8cee8c62d76139bcda299c1aa00 # v5.0.0
ARG NGHTTP3_VERSION=5613665eac0c209655db95c539291d7682a8b6a3 # v1.16.0
ARG NGTCP2_VERSION=9ccd9017e6f061d25fa890e231efb253fa18dbac # v1.23.0
ARG BROTLI_VERSION=028fb5a23661f123017c060daa546b55cf4bde29 # v1.2.0
ARG CURL_VERSION=6e3f8dc1f173b47de9a68516ce4b95bf25598c2f # curl-8_20_0

COPY git-clone-commit.sh /usr/local/bin

RUN apk upgrade --no-cache -a && \
    apk add --no-cache git clang lld compiler-rt llvm-libunwind-static libc++-dev linux-headers cmake ninja autoconf automake make libtool llvm file \
                       nghttp2-dev nghttp2-static zlib-dev zlib-static zstd-dev zstd-static perl

RUN for f in $(apk info --no-cache -qL libgcc-static libstdc++-dev); do rm /"$f"; done && \
    echo "-fuse-ld=lld --rtlib=compiler-rt --unwindlib=libunwind -stdlib=libc++ -D_LIBCPP_HARDENING_MODE=_LIBCPP_HARDENING_MODE_EXTENSIVE" | tee /etc/clang*/*.cfg

ARG CC=clang
ARG CXX=clang++
ARG LD=ld.lld
ARG AR=llvm-ar

ARG FLAGS
ARG CFLAGS="$FLAGS -m64 -O3 -pipe -flto=full -ffunction-sections -fdata-sections -fno-math-errno -ffp-contract=fast -fstack-clash-protection -fstack-protector-strong -fzero-call-used-regs=used-gpr -fstrict-flex-arrays=3 -ftrivial-auto-var-init=zero -fno-delete-null-pointer-checks -fno-strict-overflow -fno-strict-aliasing -fno-semantic-interposition -fno-plt -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=3 -Wformat=2 -Werror=format-security"
ARG CXXFLAGS="$CFLAGS"
ARG LDFLAGS="-m64 -Wl,-s -Wl,-O2 -Wl,--lto-O3 -Wl,--icf=safe -Wl,--gc-sections -Wl,-z,noexecstack -Wl,-z,relro -Wl,-z,now -Wl,--sort-common -Wl,--as-needed -Wl,-z,pack-relative-relocs -Wl,--no-copy-dt-needed-entries"

RUN git config --global advice.detachedHead false && \
    git config --global init.defaultBranch main

RUN git-clone-commit.sh https://github.com/aws/aws-lc "$AWSLC_VERSION" /src/aws-lc && \
    cd /src/aws-lc && \
    cmake /src/aws-lc -G Ninja -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DDISABLE_GO=ON -DDISABLE_PERL=ON -DBUILD_TESTING=OFF && \
    ninja install

RUN git-clone-commit.sh https://github.com/ngtcp2/nghttp3 "$NGHTTP3_VERSION" /src/nghttp3 true && \
    cd /src/nghttp3 && \
    autoreconf -fi && \
    /src/nghttp3/configure --prefix=/usr --enable-lib-only --enable-static --disable-shared && \
    make -j "$(nproc)" install

ARG BORINGSSL_LIBS="-lssl -lcrypto"
RUN git-clone-commit.sh https://github.com/ngtcp2/ngtcp2 "$NGTCP2_VERSION" /src/ngtcp2 && \
    cd /src/ngtcp2 && \
    autoreconf -fi && \
    /src/ngtcp2/configure --prefix=/usr --with-boringssl --enable-lib-only --enable-static --disable-shared && \
    make -j "$(nproc)" install

RUN git-clone-commit.sh https://github.com/google/brotli "$BROTLI_VERSION" /src/brotli && \
    cd /src/brotli && \
    cmake /src/brotli -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_SHARED_LIBS=OFF && \
    ninja install

ARG LDFLAGS="$LDFLAGS -static-pie"
RUN git-clone-commit.sh https://github.com/curl/curl "$CURL_VERSION" /src/curl && \
    cd /src/curl && \
    sed -i "s|-DEV||g" /src/curl/include/curl/curlver.h && \
    autoreconf -fi && \
    /src/curl/configure --without-libpsl --with-openssl --with-nghttp2 --with-ngtcp2 --with-nghttp3 --with-zlib --with-brotli --with-zstd --enable-httpsrr --enable-ech --enable-ntlm --enable-unity --enable-static --disable-shared --disable-docs  && \
    make -j "$(nproc)" && \
    llvm-strip -s /src/curl/src/curl && \
    ls -lh /src/curl/src/curl && \
    file /src/curl/src/curl && \
    /src/curl/src/curl -V


FROM scratch
COPY --from=build /src/curl/src/curl /usr/local/bin/curl
WORKDIR /host
ENTRYPOINT ["curl"]
CMD ["-V"]
