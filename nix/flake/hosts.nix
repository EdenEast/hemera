{
  inputs,
  self,
  lib,
  ...
}: let
  system = "x86_64-linux";
  hostsDir = ../hosts;
  hostEntries = builtins.readDir hostsDir;
  hostNames =
    builtins.filter
    (name: hostEntries.${name} == "directory")
    (builtins.attrNames hostEntries);

  mkSystem = name:
    inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        (hostsDir + "/${name}/configuration.nix")
      ];
    };

  mkHive = name: {config, ...}: {
    imports = [
      (hostsDir + "/${name}/configuration.nix")
    ];

    deployment = {
      targetHost =
        (builtins.head config.networking.interfaces.ens18.ipv4.addresses).address;
      tags =
        ["hemera"]
        ++ lib.optional (lib.hasInfix "cp" name) "control-plane"
        ++ lib.optional (lib.hasInfix "worker" name) "worker";
    };
  };
in {
  flake = {
    colmenaHive =
      inputs.colmena.lib.makeHive {
        meta = {
          nixpkgs = import inputs.nixpkgs {
            system = "x86_64-linux";
            config.allowUnfree = true;
          };
          specialArgs = {inherit self inputs;};
        };

        defaults = _: {
          deployment = {
            targetUser = "admin";
            buildOnTarget = false;
          };
        };
      }
      // lib.genAttrs hostNames mkHive;

    nixosConfigurations = inputs.nixpkgs.lib.genAttrs hostNames mkSystem;
  };
}
