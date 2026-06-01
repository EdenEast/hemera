{
  inputs,
  lib,
  ...
}: {
  imports = with lib;
    map (fn: ./${fn})
    (builtins.attrNames (
      filterAttrs (
        n: _v: (!(hasPrefix "_" n) && !(hasPrefix "default" n))
      ) (builtins.readDir ./.)
    ));

  perSystem = {system, ...}: {
    _module.args.pkgs = import inputs.nixpkgs {
      inherit system;
      config.allowUnfreePredicate = pkg:
        builtins.elem (lib.getName pkg) [
          "terraform"
        ];
    };
  };
}
