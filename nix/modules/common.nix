{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./admin-ssh-keys.nix
  ];

  nix.settings.experimental-features = ["nix-command" "flakes"];

  boot.loader.grub = {
    enable = true;
    device = "/dev/vda";
  };

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  services.qemuGuest.enable = true;

  services.openiscsi = {
    enable = true;
    name = "iqn.2026-05.local.hemera:${config.networking.hostName}";
  };

  # Longhorn expects iscsiadm at this conventional FHS path.
  systemd.tmpfiles.rules = [
    "L+ /usr/bin/iscsiadm - - - - ${pkgs.openiscsi}/bin/iscsiadm"
  ];

  users.users.admin = {
    isNormalUser = true;
    extraGroups = ["wheel"];
  };
  security.sudo.wheelNeedsPassword = false;

  environment.systemPackages = with pkgs; [
    curl
    dig
    git
    htop
    jq
    nfs-utils
    openiscsi
    tcpdump
    vim
  ];

  system.stateVersion = "26.05";
}
