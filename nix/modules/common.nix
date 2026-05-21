{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./admin-ssh-keys.nix
    ./secrets.nix
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

  boot.loader.grub = {
    enable = true;
    device = "/dev/vda";
  };

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  networking.resolvconf.extraConfig = ''
    name_servers='192.168.2.1'
  '';

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  services.qemuGuest.enable = true;

  # Longhorn runs inside Kubernetes, but every Cluster Node needs the host-side
  # tools required to attach Longhorn volumes and use NFS backup targets.
  services.openiscsi = {
    enable = true;
    name = "iqn.2026-05.local.hemera:${config.networking.hostName}";
  };

  # Longhorn checks for iscsiadm from inside a privileged pod after entering the
  # host mount namespace. On NixOS the binary lives under /run/current-system,
  # while Longhorn expects a conventional FHS path.
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
}
