{
  config,
  pkgs,
  ...
}: {
  nix.distributedBuilds = true;
  # nix.extraOptions = ''
  # builders-use-substitutes = true
  # '';

  nix.buildMachines = [
    {
      hostName = "server3-gpu"; # Must be resolvable or an IP
      system = "x86_64-linux"; # The architecture of the builder
      protocol = "ssh-ng"; # Optimized protocol
      maxJobs = 4;
      speedFactor = 2;
      supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
      mandatoryFeatures = [];
      sshUser = "synchronous";
      sshKey = "/home/synchronous/.ssh/id_ed25519"; # Path to private key on client
    }
  ];
}
