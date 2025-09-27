{
  services.kubernetes = {
    roles = ["node"];

    masterAddress = "192.168.1.100";

    kubelet.enable = true;
    proxy.enable = true;
    flannel.enable = true;

    easyCerts = true;
    pki.enable = true;

    kubelet = {
      kubeconfig.server = "https://192.168.1.100:6443";
      hostname = "worker-gpu1";
      extraOpts = "--fail-swap-on=false";
    };
  };

  virtualisation.containerd.enable = true;

  networking.firewall.allowedTCPPorts = [
    10250
  ];

  virtualisation.docker = {
    enable = true;

    # use nvidia as the default runtime
    enableNvidia = true;
    extraOptions = "--default-runtime=nvidia";
  };
}
