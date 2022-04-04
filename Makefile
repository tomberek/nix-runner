.PHONY:push run run-clean

# TODO: make it easier to pin versions

NIX_ARGS= --argstr system x86_64-linux
docker: .dockeriid

busybox:
	nix build nixpkgs#pkgsStatic.busybox
	cp ./result/bin/busybox .

nix:
	nix build nixpkgs#nixStatic
	cp ./result/bin/nix .

ca-bundle.crt:
	nix build nixpkgs#cacert
	cp ./result/etc/ssl/certs/ca-bundle.crt .

.dockeriid: Dockerfile nix busybox ca-bundle.crt os-release nix.conf
	DOCKER_BUILDKIT=1 docker build --tag tomberek/nix-runner --ssh default -t nix-runner . --iidfile .dockeriid

REGISTRY := registry.example.com/name:tag
push: .dockeriid
	docker tag nix-runner $(REGISTRY)
	docker push $(REGISTRY)

# Use local /nix/store as read-only cache
run: .dockeriid env
	docker run --rm -it --env-file env \
		-v /nix:/nix:ro nix-runner $(CMD)

# Download everything
run-env: .dockeriid env
	docker run --rm -it --env-file env \
		nix-runner $(CMD)

run-clean: .dockeriid
	docker run --rm -e -it nix-runner

clean:
	rm busybox nix ca-bundle.crt .dockeriid result
