{pkgs, ...}: {
  imports = [
    ./modules/admin-ssh-keys.nix
  ];

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = [
      "root"
      "admin"
    ];
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

  # Keep the template generic. Hostname, static networking, k3s role, and
  # secrets are applied later by each Cluster Node's NixOS configuration.
  system.stateVersion = "26.05";
}
