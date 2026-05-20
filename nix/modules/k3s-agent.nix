{config, ...}: {
  services.k3s = {
    enable = true;
    role = "agent";
    serverAddr = "https://192.168.1.50:6443";
    tokenFile = config.sops.secrets."k3s/token".path;
  };
}
