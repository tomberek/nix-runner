{
  outputs = {
    self,
    nixpkgs,
  }: {
    packages =
      nixpkgs.lib.mapAttrs (system: pkgs: {
        buildScript = pkgs.runCommand "start-docker-nix-build-slave" {} ''
          cp ${./start-docker-nix-build-slave} $out
        '';
      })
      nixpkgs.legacyPackages;
  };
}
