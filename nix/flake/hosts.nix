{
  inputs,
  self,
  lib,
  ...
}: let
  system = "x86_64-linux";
  pkgs = import inputs.nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };
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
        (builtins.head config.networking.interfaces.eth0.ipv4.addresses).address;
      tags =
        ["hemera"]
        ++ lib.optional (lib.hasInfix "cp" name) "control-plane"
        ++ lib.optional (lib.hasInfix "worker" name) "worker";

      keys."cluster-token" = {
        keyCommand = [
          "sh"
          "-c"
          ''
            set -eu
            : "''${HEMERA_AGE_KEY:?set HEMERA_AGE_KEY to the age identity file for decrypting the K3s cluster token}"
            token_file="''${HEMERA_K3S_TOKEN_AGE_FILE:-$PWD/nix/secrets/k3s-cluster-token.age}"
            exec ${pkgs.age}/bin/age -d -i "$HEMERA_AGE_KEY" "$token_file"
          ''
        ];
        destDir = "/var/lib/rancher/k3s";
        user = "root";
        group = "root";
        permissions = "0600";
        uploadAt = "pre-activation";
      };
    };
  };

  colmena =
    {
      meta = {
        nixpkgs = pkgs;
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
in {
  flake = {
    inherit colmena;
    colmenaHive = inputs.colmena.lib.makeHive colmena;
    nixosConfigurations = inputs.nixpkgs.lib.genAttrs hostNames mkSystem;
  };
}
