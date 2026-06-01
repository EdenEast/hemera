{pkgs, ...}: {
  imports = [
    ../../modules/admin-ssh-keys.nix
  ];

  services.cloud-init = {
    enable = true;
  };

  services.qemuGuest.enable = true;
  services.openssh.enable = true;

  nix.settings.experimental-features = ["nix-command" "flakes"];

  users.users.admin = {
    isNormalUser = true;
    extraGroups = ["wheel"];
  };
  security.sudo.wheelNeedsPassword = false;

  environment.systemPackages = with pkgs; [
    curl
    git
    htop
    vim
  ];

  # Hostname, IP, k3s role, Longhorn disks, and secrets are applied later.
  system.stateVersion = "26.05";
}
