{
  outputs = {
    self,
    nixpkgs,
  }: {
    packages =
      nixpkgs.lib.mapAttrs (system: pkgs: {
        builderScript = pkgs.writeShellScript "start-docker-nix-build-slave" ''
          PATH=$PATH:${nixpkgs.lib.makeBinPath (with pkgs; [jq curl])}
          source ${./start-docker-nix-build-slave}
        '';
      })
      nixpkgs.legacyPackages;
  };
}
