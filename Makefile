.PHONY:push run run-clean

# TODO: make it easier to pin versions

NIX_ARGS= --argstr system x86_64-linux
docker: .dockeriid

busybox:
	nix-build '<nixpkgs>' ${NIX_ARGS} -A pkgsStatic.busybox
	cp ./result/bin/busybox .

nix:
	nix-build -I dtz-nur=https://github.com/dtzWill/nur-packages/archive/master.tar.gz '<dtz-nur>' ${NIX_ARGS} -A pkgs.nix-mux
	cp ./result/bin/nix .
	# TODO
	#curl https://matthewbauer.us/nix > nix

ca-bundle.crt:
	nix-build '<nixpkgs>' ${NIX_ARGS} -A cacert
	cp ./result/etc/ssl/certs/ca-bundle.crt .

.dockeriid: Dockerfile nix busybox ca-bundle.crt
	docker build -t nix-runner . --iidfile .dockeriid

REGISTRY := registry.example.com/name:tag
push: .dockeriid
	docker tag nix-runner $(REGISTRY)
	docker push $(REGISTRY)

# Use local /nix/store as read-only cache
run: .dockeriid env
	docker run --rm -it --env-file env \
		-v /nix:/nix:ro nix-runner $(CMD)

# Download everything
run-clean: .dockeriid env
	docker run --rm -it --env-file env \
		nix-runner $(CMD)

clean:
	rm busybox nix ca-bundle.crt .dockeriid result
