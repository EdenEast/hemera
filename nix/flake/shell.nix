_: {
  perSystem = {
    config,
    pkgs,
    inputs',
    lib,
    ...
  }: let
    terraformWithDefaultDir = pkgs.writeShellScriptBin "terraform" ''
      root="$(${pkgs.git}/bin/git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || pwd)"
      exec ${pkgs.terraform}/bin/terraform -chdir="$root/terraform/proxmox" "$@"
    '';
  in {
    devShells.default = pkgs.mkShell {
      name = "hemera";
      inputsFrom = [config.flake-root.devShell];
      packages = with pkgs; [
        terraformWithDefaultDir
        inputs'.colmena.packages.colmena
        helmfile
        just
        k9s
        kubectl
        kubernetes-helm
        kubeseal
        ssh-to-age
        config.treefmt.build.wrapper
      ];

      shellHook = ''
        KUBECONFIG="$(${lib.getExe config.flake-root.package})/generated/kubeconfig";
        export KUBECONFIG
      '';
    };
  };
}
