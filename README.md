# Shorts

This is a monorepo for an excercise in writing an http server using `:gen_tcp` to shorten URLS and a nif using [wyhash] (https://github.com/wangyi-fudan/wyhash/) to hash urls.

## Shorts (Server) Overview

### Usage

The server is designed to shorten urls, it handles two requests:

#### Create a Short URL

Make `POST` on `/u` with a json object containing a `url` property with a value set to the `url` you wish to shorten.

##### Example
```shell
curl -X POST http://localhost:4020/u \
  -d '{"url": "http://yer-url-goes-ere.edu/de"}'
```

The response contains a similar payload, but the url will by the path to the shortened `url`.

##### Example
```json
{"url": "/u/H3XV4LU3H3R3"}
```

##### Fetch a Short URL

1. `GET` on `/u/` with the _short url_ created above, and be redirected to
the original url.

`curl -X GET http://localhost:4020/u`

### Design

Shorts internally has one process which listens on the socket, and then creates a child `Acceptor` processsfor reading and writing from/to the socket.


Internally, shorts creates a pool of acceptors to listen to multiple requests at once and prevent blocking.

## WyhashEx Overview

To be honest, I have no idea how the hashing function works. It might as well be magic to me...

### Usage

The hashing function accepts charlists and returns an `long long` (?)
```
iex> WyhashEx.hash('charlist')
8725499900194858456
```

Within the nif code, a seed value has been set to `1024` to provide consistent hashing. It could be configured at runtime, but that improvement has yet to be made.
