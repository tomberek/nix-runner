# Nix Docker Utils
Experiments in containers


## Nix In Docker Builder
Start Nix in a Docker container such that it can serve as a remote builder.

```
source $(nix build github:tomberek/nix-runner#builderScript --print-out-paths)
```

## Container built by Nix
With some niceties like pre-loaded and pinned nixpkgs, tab-completion, and cached searching.

```shell
nix build
docker load < ./result
docker run --rm -it docker.io/tomberek/nix-runner:pure-nix
```

## Custom image build with a Dockerfile
```
make -C dockerfile-root/
docker run --rm -it docker.io/tomberek/nix-runner:pure-docker
```

## Container built by BuildKit-Nix
Using [BuildKit-Nix](https://github.com/AkihiroSuda/buildkit-nix)

- [ ] broken at the moment

```shell
DOCKER_BUILDKIT=1 docker build -t docker.io/tomberek/nix-runner:buildkit-nix -f flake.nix .
docker run --rm -it kit-nix
```

## Random
```
nix store gc --option keep-derivations false && nix path-info --all -sSh | sort -hk2
```

### Why use this?
If you want to use Nix, but don't want to build a container using Nix tooling, these are minimal containers that can fetch everything it needs during runtime given the proper environment variables and access to the correct binary caches. Updating the environment variables and bouncing the containers makes for quick and easy update of services.

### References
Some ideas from https://github.com/teamniteo/nix-docker-base/blob/master/image.nix
