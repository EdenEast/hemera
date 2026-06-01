{inputs, ...}: {
  perSystem = _: {
    packages = {
      proxmox-cloud-init-template =
        (inputs.nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            "${inputs.nixpkgs}/nixos/modules/virtualisation/proxmox-image.nix"
            ./configuration.nix
          ];
        }).config.system.build.VMA;
    };
  };
}
