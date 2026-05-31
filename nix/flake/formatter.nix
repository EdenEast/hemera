{inputs, ...}: {
  imports = [inputs.treefmt-nix.flakeModule];

  perSystem.treefmt.programs = {
    # nix
    alejandra.enable = true;
    deadnix.enable = true;
    statix.enable = true;

    # kubernetes and teraform manifest
    prettier = {
      enable = true;
      includes = [
        "*.json"
        "*.yaml"
        "*.yml"
      ];
    };
    terraform.enable = true;

    # shell scripting
    shellcheck.enable = true;
    shfmt.enable = true;
  };
}
