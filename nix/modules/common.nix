{pkgs, ...}: {
  imports = [
    ./secrets.nix
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
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

  users.users.admin = {
    isNormalUser = true;
    extraGroups = ["wheel"];
    openssh.authorizedKeys.keys = [
      # TODO_CONFIRM: replace with the real Hemera admin workstation public key.
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIReplaceWithHemeraAdminPublicKey hemera-admin-placeholder"
    ];
  };

  security.sudo.wheelNeedsPassword = false;

  environment.systemPackages = with pkgs; [
    curl
    dig
    git
    htop
    jq
    tcpdump
    vim
  ];
}
