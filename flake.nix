# syntax = ghcr.io/akihirosuda/buildkit-nix:v0.0.2@sha256:ad13161464806242fd69dbf520bd70a15211b557d37f61178a4bf8e1fd39f1f2
{
  outputs = {
    self,
    nixpkgs,
  }: {
    checks = self.packages;
    packages =
      nixpkgs.lib.mapAttrs (system: pkgs: rec {
        builderScript = pkgs.writeShellScript "start-docker-nix-build-slave" ''
          PATH=$PATH:${nixpkgs.lib.makeBinPath (with pkgs; [jq curl])}
          source ${./start-docker-nix-build-slave}
        '';

        default = oci;
        oci = with pkgs; let
          tools = [
            bashInteractive
            coreutils
            openssh
            gitMinimal
            gnugrep
            gnutar
            gzip
            bash-completion
            nixStatic
          ];
          registry = runCommand "registry" {} ''
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
          cache = runCommand "registry" {} ''
            export NIX_REMOTE=local?root=$PWD
            export HOME=$PWD
            export NIX_CONFIG='extra-experimental-features = nix-command flakes
            flake-registry = ${registry}/etc/nix/registry.json
            '
            ${nixStatic}/bin/nix --offline search nixpkgs hello
            mkdir -p $out/root/.cache/nix
            cp -r .cache/nix/eval-cache-v* $out/root/.cache/nix/
          '';
          profile = runCommand "profile" {} ''
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
          dockerTools.buildImage {
            name = "docker.io/tomberek/nix-runner";
            tag = "pure-nix";
            created = "now";
            copyToRoot = buildEnv {
              name = "wrapper";
              paths = [
                ./root
                dockerTools.binSh
                dockerTools.fakeNss
                dockerTools.usrBinEnv
                dockerTools.caCertificates
                bash-completion
                nixStatic
                cache
                registry
                profile
              ];
              ignoreCollisions = true;
              #pathsToLink = ["/bin" "/lib" "/etc" "/var"];
            };

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
                export USER=nobody
                ${buildPackages.nix}/bin/nix-store --load-db < ${closureInfo {rootPaths = contentsList;}}/registration
                mkdir -p nix/var/nix/gcroots/docker/
                for i in ${lib.concatStringsSep " " contentsList}; do
                ln -s $i nix/var/nix/gcroots/docker/$(basename $i)
                done;
              '';
            in [mkDbExtraCommand];
            config = {
              Cmd = ["${bashInteractive}"];
              Env = [
                # copied from https://github.com/teamniteo/nix-docker-base/commit/0a5ceed0441a32b25a33b6904a47e007231b58c6
                # By default, the linker added in dynamicRootFiles can only find glibc
                # libraries, but the node binary from the GitHub Actions runner also
                # depends on libstdc++.so.6, which is glibc/stdenv. Using LD_LIBRARY_PATH
                # is the easiest way to inject this dependency
                "LD_LIBRARY_PATH=${lib.makeLibraryPath [ pkgs.stdenv.cc.cc ]}"
                "XDG_DATA_DIRS=/share"
                "PAGER=${less}/bin/less"
                "NIXPKGS=${nixpkgs}"
                "PATH=${
                  buildEnv {
                    name = "tools";
                    paths = tools;
                  }
                }/bin"
              ];
              Entrypoint = ["sh" "-c" "nix shell \${CMD-$0 $@}"];
              WorkingDir = "/tmp";
            };
          };
      })
      (
        builtins.removeAttrs nixpkgs.legacyPackages ["mipsel-linux" "armv5tel-linux" "aarch64-darwin" "x86_64-darwin" "riscv64-linux"]
      );
  };
}
