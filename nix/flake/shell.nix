{...}: {
  perSystem = {
    config,
    pkgs,
    ...
  }: {
    devShells.default = pkgs.mkShell {
      name = "hemera";
      packages = with pkgs; [
        colmena
        just
        k9s
        kubectl
        terraform
      ];
    };
  };
}
