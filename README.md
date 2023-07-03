# neard-nix

[NEAR node](https://github.com/near/nearcore) Nix derivation for `x86_64-linux`, `aarch64-darwin` and `x86_64-darwin`

This targets latest stable and RC versions.

## Docker images

See [docker.io/zentria/neard-nix](https://hub.docker.com/r/zentria/neard-nix/tags)  
See [ghcr.io/zentriamc/neard-nix/neard](https://github.com/ZentriaMC/neard-nix/pkgs/container/neard-nix%2Fneard)

### Verifying image signature

Images are signed by following cosign public key:

```
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAERRR+2JjyGLI6C6aidYjM8nPXYMT+
hPpXmirJASHFSsrGBAsawCtCw8GDz894OlUHydZJVcNSxJfm8PoFBYbgfw==
-----END PUBLIC KEY-----
```

Save public key to `zentria-neard.pub` and use:

```shell
$ cosign verify --key zentria-neard.pub docker.io/zentria/neard-nix:1.34.0
```

## Cache

Note: only x86\_64-linux is cached automatically.

URL: `https://zentria-near.cachix.org`  
Public key: `zentria-near.cachix.org-1:BKvOv13hKSkWX5RZpLs9Da5b5ZCySBdYFWukCvR5YVY=`

## Donate

NEAR: `zentria.near`
