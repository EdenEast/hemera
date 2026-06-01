_: {
  perSystem = {
    config,
    pkgs,
    ...
  }: {
    devShells.default = pkgs.mkShell {
      name = "hemera";
      packages = with pkgs; [
        age
        colmena
        curl
        git
        helmfile
        jq
        just
        k9s
        kubectl
        kubernetes-helm
        kubeseal
        opentofu
        sops
        ssh-to-age
        terraform
        yq-go
        config.treefmt.build.wrapper
      ];
    };
  };
}
