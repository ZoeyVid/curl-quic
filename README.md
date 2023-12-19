# curl-quic

## Usage:

```sh
docker run --rm -it --pull always --name curl -v "/:/host" zoeyvid/curl-quic
```

### Example:

```sh
docker run --rm -it --pull always --name curl -v "/:/host" zoeyvid/curl-quic --http3 -sL https://quic.nginx.org -o /host/root/curl-output
cat /root/curl-output
```
