{self, ...}: {
  perSystem = {
    config,
    pkgs,
    ...
  }: {
    devShells.default = pkgs.mkShell {
      inputsFrom = [config.flake-root.devShell];
      name = "hemera";
      packages = with pkgs; [
        just
        k9s
        kubectl
        terraform
        treefmtEval.config.build.wrapper
      ];
    };
  };
}
