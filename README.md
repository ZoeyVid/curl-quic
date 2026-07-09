# curl-quic

This docker image/the release files contain a statically linked build of curl based on awslc, zlib-ng, nghttp2, ngtcp2, nghttp3 and more.

## Usage:

```sh
docker run --rm --pull always zoeyvid/curl-quic
```

### Example:

```sh
docker run --rm --pull always -v "/:/host" zoeyvid/curl-quic --http3 -vsSfL https://quic.nginx.org -o root/curl-output
cat /root/curl-output
```
