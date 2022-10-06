# Nix Runner

Use Nix inside docker. Build the container during runtime.

# Nix In Docker Builder
Start Nix in a Docker container such that it can serve as a remote builder.

```
 source $(nix build github:tomberek/nix-runner#builderScript --print-out-paths)
```

TODO: something to easily reset/undo

## Building
```shell
make
make run
```

## Running examples
The ENTRYPOINT and CMD are designed to allow providing commands via an env-file or on the command line. Normal non-tutorial usage would usually require referencing a [nix environment](https://nixos.org/nixpkgs/manual/#sec-building-environment) rather than a raw package.

```shell
docker run --rm -it nix-runner uname -a
docker run --rm -it nix-runner ls /nix/store/\* -d -1
docker run --rm -it -e ENV_PATH=/nix/store/pyvdjig3g8ifavyiqrq8bbj7mz4xwsjl-cowsay-3.03+dfsg2 nix-runner cowsay blarg
docker run --rm -it -v /nix:/nix:ro -e ENV_PATH=/nix/store/pyvdjig3g8ifavyiqrq8bbj7mz4xwsjl-cowsay-3.03+dfsg2 nix-runner cowsay blarg
```

## Basic coreutils environment in the example Dockerfile
```shell
docker run --rm -it nix-runner ls /nix/store/\* -d -1
/nix/store/8p804y3l03gfdjdlsc90v6xmjzwv65fw-attr-2.4.48
/nix/store/9l6d9k9f0i9pnkm7xicpzn4cv2c-libidn2-2.3.0
/nix/store/bwzra330vib0ik4d3l8rq6gp6y2ah1fr-glibc-2.30
/nix/store/ca9mkrf8sa8md8pv61jslhcnfk9mmg4p-coreutils-8.31
/nix/store/pgj5vsdly7n4rc8jax3x3sill06l44qp-libunistring-0.9.10
/nix/store/s1fa3s9ynpn2l19bzd811qlifv5rxs75-acl-2.2.53
```

### Discussion
This concept is somewhat similar to [Nixery](https://nixery.dev/) but has different pros/cons. The distinction is that the container may fetch any/all runtime dependencies during startup. The container itself is just a passthrough and hardly matters, it is there just to allow standard container management services to do orchestration.

### Why use this?
If you want to use Nix, but don't want to build a container using Nix tooling, this is a minimal container that can fetch everything it needs during runtime given the proper environment variables and access to the correct binary caches. Updating the environment variables and bouncing the containers makes for quick and easy update of services.
