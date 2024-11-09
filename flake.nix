# syntax = ghcr.io/akihirosuda/buildkit-nix:v0.0.2@sha256:ad13161464806242fd69dbf520bd70a15211b557d37f61178a4bf8e1fd39f1f2
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  outputs = {
    self,
    nixpkgs,
  }: {
    checks = self.packages;
    packages =
      nixpkgs.lib.recursiveUpdate (
        nixpkgs.lib.mapAttrs (system: pkgs: rec {
          builderScript = pkgs.writeShellScript "start-docker-nix-build-slave" ''
            PATH=$PATH:${nixpkgs.lib.makeBinPath (with pkgs; [jq curl])}
            source ${./start-docker-nix-build-slave}
          '';
        })
        nixpkgs.legacyPackages
      )
      (nixpkgs.lib.mapAttrs (system: pkgs: rec {
          default = oci;
          oci = let
            tools = [
              pkgs.bashInteractive
              pkgs.coreutils
              pkgs.openssh
              pkgs.gitMinimal
              pkgs.gnugrep
              pkgs.gnutar
              pkgs.gzip
              pkgs.bash-completion
              pkgs.nixVersions.latest
            ];
            registry = pkgs.runCommand "registry" {} ''
              mkdir -p $out/etc/nix
              cat > $out/etc/nix/registry.json <<EOF
              {
                "flakes": [
                  {
                    "from": {
                      "id": "n",
                      "type": "indirect"
                    },
                    "to": {
                      "lastModified": 0,
                      "narHash": "${nixpkgs.sourceInfo.narHash}",
                      "path": "${nixpkgs}",
                      "type": "path"
                    }
                  },
                  {
                    "from": {
                      "id": "nixpkgs",
                      "type": "indirect"
                    },
                    "to": {
                      "lastModified": 0,
                      "narHash": "${nixpkgs.sourceInfo.narHash}",
                      "path": "${nixpkgs}",
                      "type": "path"
                    }
                  }
                ],
                "version": 2
              }
              EOF
            '';
            cache = pkgs.runCommand "registry" {} ''
              export NIX_REMOTE=local?root=$PWD
              export HOME=$PWD
              export NIX_CONFIG='extra-experimental-features = nix-command flakes
              flake-registry = ${registry}/etc/nix/registry.json
              '
              ${pkgs.nixStatic}/bin/nix --offline search nixpkgs hello
              mkdir -p $out/root/.cache/nix
              cp -r .cache/nix/eval-cache-v* $out/root/.cache/nix/

              mkdir -p $out/home/user/.cache/nix
              cp -r .cache/nix/eval-cache-v* $out/home/user/.cache/nix/
            '';
            profile = pkgs.runCommand "profile" {} ''
              mkdir -p $out/etc
              mkdir -p $out/root/
              cat > $out/etc/profile <<EOF
              . /etc/profile.d/bash_completion.sh
              alias n='nix'
              alias registry='nix registry'
              alias run='nix run'
              alias store='nix store'
              alias shell='nix shell'
              alias develop='nix develop'
              alias flake='nix flake'
              EOF
              mkdir -p $out/bin
              cat > $out/bin/n << 'EOF'
              #!/bin/sh
              nix "$@"
              EOF
              cat > $out/bin/run << 'EOF'
              #!/bin/sh
              nix run "$@"
              EOF
              cat > $out/bin/shell << 'EOF'
              #!/bin/sh
              nix shell "$@"
              EOF
              chmod +x $out/bin/*
              ln -s /etc/profile $out/root/.bashrc
              # copied from https://github.com/teamniteo/nix-docker-base/commit/0a5ceed0441a32b25a33b6904a47e007231b58c6
              # So that this image can be used as a GitHub Action container directly
              # Needed because it calls its own (non-nix-patched) node binary which uses
              # this dynamic linker path. See also the LD_LIBRARY_PATH assignment below,
              # which provides the necessary libraries for that binary
              mkdir $out/lib64
              ln -s ${pkgs.glibc}/lib/ld-linux-x86-64.so.2 $out/lib64/ld-linux-x86-64.so.2
            '';
          in
            pkgs.dockerTools.buildImage {
              name = "docker.io/tomberek/nix-runner";
              tag = "pure-nix";
              created = "now";
              copyToRoot = pkgs.buildEnv {
                name = "wrapper";
                paths = [
                  ./root
                  pkgs.dockerTools.binSh
                  pkgs.dockerTools.fakeNss
                  pkgs.dockerTools.usrBinEnv
                  pkgs.dockerTools.caCertificates
                  pkgs.bash-completion
                  pkgs.nixVersions.latest
                  cache
                  registry
                  profile
                ];
                ignoreCollisions = true;
                #pathsToLink = ["/bin" "/lib" "/etc" "/var"];
              };

              runAsRoot = ''
                  mkdir -p /home/user
                  ln -s /etc/profile /home/user/.bashrc
                  mkdir -p /nix/var/nix/profiles/per-user/user
                  mkdir -p /nix/var/nix/gcroots/
                  mkdir -p /nix/var/nix/temproots/
                  mkdir -p /nix/var/nix/db
                  touch /nix/var/nix/gc.lock

                  chown 1000 -R /nix/var/nix
                  chgrp 1000 -R /nix/var/nix
                  chmod 755 -R /nix/var/nix
                  chown 1000 -R /home/user
                  chgrp 1000 -R /home/user
                  chmod 755 -R /home/user
              '';
              extraCommands = let
                contentsList =
                  [nixpkgs]
                  ++ (
                    if builtins.isList tools
                    then tools
                    else [tools]
                  );
                mkDbExtraCommand = ''
                  echo "Generating the nix database..."
                  echo "Warning: only the database of the deepest Nix layer is loaded."
                  echo "         If you want to use nix commands in the container, it would"
                  echo "         be better to only have one layer that contains a nix store."
                  export NIX_REMOTE=local?root=$PWD
                  # A user is required by nix
                  # https://github.com/NixOS/nix/blob/9348f9291e5d9e4ba3c4347ea1b235640f54fd79/src/libutil/util.cc#L478
                  export USER=user
                  ${pkgs.buildPackages.nix}/bin/nix-store --load-db < ${pkgs.closureInfo {rootPaths = contentsList;}}/registration
                  mkdir -p nix/var/nix/gcroots/docker/
                  for i in ${pkgs.lib.concatStringsSep " " contentsList}; do
                  ln -s $i nix/var/nix/gcroots/docker/$(basename $i)
                  done;
                  chown 1000 -R nix
                '';
              in mkDbExtraCommand;
              config = {
                Cmd = ["${pkgs.bashInteractive}"];
                User = "user";
                Env = [
                  # copied from https://github.com/teamniteo/nix-docker-base/commit/0a5ceed0441a32b25a33b6904a47e007231b58c6
                  # By default, the linker added in dynamicRootFiles can only find glibc
                  # libraries, but the node binary from the GitHub Actions runner also
                  # depends on libstdc++.so.6, which is glibc/stdenv. Using LD_LIBRARY_PATH
                  # is the easiest way to inject this dependency
                  "LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [pkgs.stdenv.cc.cc.lib]}"
                  "XDG_DATA_DIRS=/share"
                  "PAGER=${pkgs.less}/bin/less"
                  "NIXPKGS=${nixpkgs}"
                  "PATH=/root/.nix-profile/bin:/home/user/.nix-profile/bin:${
                    pkgs.buildEnv {
                      name = "tools";
                      paths = tools;
                    }
                  }/bin:/usr/bin:/bin"
                  # TODO: Known issue with HOME warning: https://github.com/actions/runner/issues/863
                ];
                Entrypoint = ["sh" "-c" "nix shell \${CMD-$0 $@}"];
                WorkingDir = "/tmp";
              };
            };
        })
        (
          builtins.removeAttrs nixpkgs.legacyPackages ["mipsel-linux" "armv5tel-linux" "aarch64-darwin" "x86_64-darwin" "riscv64-linux"]
        ));
  };
}
