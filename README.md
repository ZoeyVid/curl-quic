# curl-quic

This docker image contains/the release files are a statically linked build of curl based on wolfssl, zlib, nghttp2, ngtcp2 and nghttp3.

## Usage:

```sh
docker run --rm -it --pull always --name curl -v "/:/host" zoeyvid/curl-quic
```

### Example:

```sh
docker run --rm -it --pull always --name curl -v "/:/host" zoeyvid/curl-quic --http3 -sL https://quic.nginx.org -o /host/root/curl-output
cat /root/curl-output
```
