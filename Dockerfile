# syntax=docker/dockerfile:1.28.0@sha256:bb22d9815c728170f72750f4e5b0d672e06176142e1d602c7e66c050100b7e5b
FROM alpine:3.24.3@sha256:be2656061b536c1883c4034790e21d0a09c5aaaf51968b89368a3c0371ea2c9a AS build
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

ARG AWSLC_VERSION=cd481c207e38f06aeb5766f4a1cdfce10a4c0af8 # v5.12.0
ARG NGTCP2_VERSION=f9e9ff01ad2c8116bc09de4f644b0028a61486a6 # v1.25.0
ARG NGHTTP3_VERSION=dbfc24286138cb0b6490160e7ca87fe1ce6722a0 # v1.18.0
ARG NGHTTP2_VERSION=85e300c79fb6dbcfa9c1013215c8710c1c2cd3d2 # v1.70.0
ARG ZSTD_VERSION=f8745da6ff1ad1e7bab384bd1f9d742439278e99 # v1.5.7
ARG BROTLI_VERSION=db24a98aed38a16de78cc05ca15cdd8dc2a0d92d # v1.2.1
ARG ZLIBNG_VERSION=12731092979c6d07f42da27da673a9f6c7b13586 # 2.3.3
ARG CARES_VERSION=bc91829cce983a35ec01f5dbc05465858a3df469 # v1.34.9
ARG LIBUNISTRING_VERSION=1.5
ARG LIBUNISTRING_SHA256=5b0ecd46cbf225375f20ab4056197e66a7ac590e2684c069af407ae3383c9d81
ARG LIBIDN2_VERSION=2.3.8
ARG LIBIDN2_SHA256=f557911bf6171621e1f72ff35f5b1825bb35b52ed45325dcdee931e5d3c0787a
ARG LIBPSL_VERSION=c486db8d221cbac55f87508d4da4db4497760997 # 0.23.3
ARG CURL_VERSION=3163ec065643ba20709f190111f42c3e1fe95273 # curl-8_23_0

COPY git-clone-commit.sh /usr/local/bin

RUN apk upgrade --no-cache -a && \
    apk add --no-cache git clang lld compiler-rt llvm-libunwind-static libc++-dev cmake ninja pkgconf llvm file perl meson make

RUN for f in $(apk info --no-cache -qL libgcc-static libstdc++-dev); do rm /"$f"; done && \
    echo "-fuse-ld=lld --rtlib=compiler-rt --unwindlib=libunwind -stdlib=libc++ -D_LIBCPP_HARDENING_MODE=_LIBCPP_HARDENING_MODE_EXTENSIVE" | tee /etc/clang*/*.cfg

ARG CC=clang
ARG CXX=clang++
ARG LD=ld.lld
ARG AR=llvm-ar

ARG FLAGS
ARG CFLAGS="$FLAGS -m64 -O3 -pipe -flto=full -ffunction-sections -fdata-sections -fno-math-errno -ffp-contract=fast -fstack-clash-protection -fstack-protector-strong -fzero-call-used-regs=used-gpr -fstrict-flex-arrays=3 -ftrivial-auto-var-init=zero -fno-delete-null-pointer-checks -fno-strict-overflow -fno-strict-aliasing -fno-semantic-interposition -fno-plt -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=3 -Wformat=2 -Werror=format-security"
ARG CXXFLAGS="$CFLAGS"
ARG LDFLAGS="-m64 -L/usr/local/lib -Wl,-s -Wl,-O2 -Wl,--lto-O3 -Wl,--icf=safe -Wl,--gc-sections -Wl,-z,noexecstack -Wl,-z,relro -Wl,-z,now -Wl,--sort-common -Wl,--as-needed -Wl,-z,pack-relative-relocs -Wl,--no-copy-dt-needed-entries"

RUN git config --global advice.detachedHead false && \
    git config --global init.defaultBranch main

RUN git-clone-commit.sh https://github.com/aws/aws-lc "$AWSLC_VERSION" /src/aws-lc && \
    cd /src/aws-lc && \
    cmake /src/aws-lc -G Ninja -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DDISABLE_GO=ON -DDISABLE_PERL=ON -DBUILD_TOOL=OFF -DBUILD_TESTING=OFF && \
    ninja install

ARG BORINGSSL_LIBS="-lssl -lcrypto"
RUN git-clone-commit.sh https://github.com/ngtcp2/ngtcp2 "$NGTCP2_VERSION" /src/ngtcp2 && \
    cd /src/ngtcp2 && \
    cmake /src/ngtcp2 -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local -DBUILD_SHARED_LIBS=OFF -DENABLE_SHARED_LIB=OFF -DENABLE_LIB_ONLY=ON -DENABLE_OPENSSL=OFF -DENABLE_BORINGSSL=ON -DBUILD_TESTING=OFF && \
    ninja install

RUN git-clone-commit.sh https://github.com/ngtcp2/nghttp3 "$NGHTTP3_VERSION" /src/nghttp3 true && \
    cd /src/nghttp3 && \
    cmake /src/nghttp3 -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local -DBUILD_SHARED_LIBS=OFF -DENABLE_SHARED_LIB=OFF -DENABLE_LIB_ONLY=ON -DBUILD_TESTING=OFF && \
    ninja install

RUN git-clone-commit.sh https://github.com/nghttp2/nghttp2 "$NGHTTP2_VERSION" /src/nghttp2 && \
    cd /src/nghttp2 && \
    cmake /src/nghttp2 -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local -DBUILD_SHARED_LIBS=OFF -DBUILD_STATIC_LIBS=ON -DENABLE_LIB_ONLY=ON -DENABLE_FAILMALLOC=OFF -DBUILD_TESTING=OFF -DENABLE_DOC=OFF && \
    ninja install

RUN git-clone-commit.sh https://github.com/facebook/zstd "$ZSTD_VERSION" /src/zstd && \
    cd /src/zstd && \
    cmake /src/zstd/build/cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local -DBUILD_SHARED_LIBS=OFF -DZSTD_BUILD_SHARED=OFF -DZSTD_BUILD_PROGRAMS=OFF && \
    ninja install

RUN git-clone-commit.sh https://github.com/google/brotli "$BROTLI_VERSION" /src/brotli && \
    cd /src/brotli && \
    cmake /src/brotli -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local -DBUILD_SHARED_LIBS=OFF -DBROTLI_BUILD_TOOLS=OFF && \
    ninja install

RUN git-clone-commit.sh https://github.com/zlib-ng/zlib-ng "$ZLIBNG_VERSION" /src/zlibng && \
    cd /src/zlibng && \
    cmake /src/zlibng -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local -DBUILD_SHARED_LIBS=OFF -DZLIB_COMPAT=ON -DBUILD_TESTING=OFF && \
    ninja install

RUN git-clone-commit.sh https://github.com/c-ares/c-ares "$CARES_VERSION" /src/cares && \
    cd /src/cares && \
    cmake /src/cares -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local -DBUILD_SHARED_LIBS=OFF -DCARES_SHARED=OFF -DCARES_STATIC=ON -DCARES_BUILD_TOOLS=OFF && \
    ninja install

RUN mkdir -p /src/libunistring && \
    cd /src/libunistring && \
    wget -q "https://ftp.gnu.org/gnu/libunistring/libunistring-$LIBUNISTRING_VERSION.tar.gz" && \
    echo "$LIBUNISTRING_SHA256  libunistring-$LIBUNISTRING_VERSION.tar.gz" | sha256sum -c - && \
    tar -xf "libunistring-$LIBUNISTRING_VERSION.tar.gz" --strip-components=1 && \
    ./configure --prefix=/usr/local --disable-shared --enable-static && \
    make -j "$(nproc)" && \
    make install

RUN mkdir -p /src/libidn2 && \
    cd /src/libidn2 && \
    wget -q "https://ftp.gnu.org/gnu/libidn/libidn2-$LIBIDN2_VERSION.tar.gz" && \
    echo "$LIBIDN2_SHA256  libidn2-$LIBIDN2_VERSION.tar.gz" | sha256sum -c - && \
    tar -xf "libidn2-$LIBIDN2_VERSION.tar.gz" --strip-components=1 && \
    ./configure --prefix=/usr/local --disable-shared --enable-static --disable-doc && \
    make -j "$(nproc)" && \
    make install

RUN git-clone-commit.sh https://github.com/rockdaboot/libpsl "$LIBPSL_VERSION" /src/libpsl true && \
    cd /src/libpsl && \
    meson setup build --prefix=/usr/local --buildtype=release --default-library=static -Druntime=libidn2 -Dtests=false && \
    meson install -C build

ARG LDFLAGS="$LDFLAGS -static-pie -lunistring"
RUN git-clone-commit.sh https://github.com/curl/curl "$CURL_VERSION" /src/curl && \
    cd /src/curl && \
    sed -i "s|-DEV||g" /src/curl/include/curl/curlver.h && \
    cmake /src/curl -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
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
