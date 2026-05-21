{
  description = "Hemera NixOS configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    sops-nix.url = "github:Mic92/sops-nix";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs = {
    self,
    nixpkgs,
    sops-nix,
    treefmt-nix,
    ...
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfreePredicate = pkg:
        builtins.elem (nixpkgs.lib.getName pkg) [
          "terraform"
        ];
    };
    treefmtEval = treefmt-nix.lib.evalModule pkgs {
      projectRootFile = "flake.nix";

      programs = {
        alejandra.enable = true;
        prettier = {
          enable = true;
          includes = [
            "*.json"
            "*.yaml"
            "*.yml"
          ];
        };
        shellcheck.enable = true;
        shfmt.enable = true;
        terraform.enable = true;
      };

      settings.formatter = {
        prettier.excludes = [
          "flake.lock"
          "terraform/proxmox/.terraform.lock.hcl"
        ];
        shfmt.includes = [
          "scripts/*"
          "scripts/lib/*"
        ];
      };
    };
    mkHost = hostPath:
      nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          sops-nix.nixosModules.sops
          hostPath
        ];
      };
  in {
    formatter.${system} = treefmtEval.config.build.wrapper;

    checks.${system}.formatting = treefmtEval.config.build.check self;

    packages.${system}.proxmox-template =
      (nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          "${nixpkgs}/nixos/modules/virtualisation/proxmox-image.nix"
          ./nix/proxmox-template.nix
        ];
      }).config.system.build.VMA;

    devShells.${system}.default = pkgs.mkShell {
      packages = with pkgs; [
        age
        direnv
        jq
        k9s
        kubectl
        kubernetes-helm
        kubernetes-helmPlugins.helm-diff
        helmfile
        nixos-rebuild
        openssh
        shellcheck
        sops
        ssh-to-age
        terraform
        treefmtEval.config.build.wrapper
        yq-go
      ];

      HELM_PLUGINS = "${pkgs.kubernetes-helmPlugins.helm-diff}";

      shellHook = ''
        echo ""
        echo " ██  ██ ▄▄▄▄▄ ▄▄   ▄▄ ▄▄▄▄▄ ▄▄▄▄   ▄▄▄"
        echo " ██████ ██▄▄  ██▀▄▀██ ██▄▄  ██▄█▄ ██▀██"
        echo " ██  ██ ██▄▄▄ ██   ██ ██▄▄▄ ██ ██ ██▀██"
        echo ""
      '';
    };

    nixosConfigurations = {
      k8s-cp-01 = mkHost ./nix/hosts/k8s-cp-01/configuration.nix;
      k8s-worker-01 = mkHost ./nix/hosts/k8s-worker-01/configuration.nix;
      k8s-worker-02 = mkHost ./nix/hosts/k8s-worker-02/configuration.nix;
    };
  };
}
