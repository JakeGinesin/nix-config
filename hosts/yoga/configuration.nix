{
  config,
  pkgs,
  lib,
  ...
}: {
  # import system, hardware config, and home manager
  imports = [
    ./hardware-configuration.nix
    ../../system/system.nix
  ];

  options = {
    res = lib.mkOption {
      type = lib.types.str;
      default = "1920x1080";
      description = "screen resolution";
    };
  };

  config = {
    networking.hostName = "yoga"; # Define your hostname.
    res = "1920x1080";

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "backup";
      users.synchronous.imports = [../../home/home.nix];
    };

    age = {
      secrets.zsh_remote = {
        file = ../../secrets/zsh_remote.age;
        owner = "synchronous";
        mode = "0400";
      };
      secrets.tailscale-rq = {
        file = ../../secrets/tailscale-rq.age;
        owner = "synchronous";
        mode = "0400";
      };
      secretsDir = "/home/synchronous/.agenix/agenix";
      secretsMountPoint = "/home/synchronous/.agenix/agenix.d";
      identityPaths = ["/home/synchronous/.ssh/id_ed25519"];
    };

    boot.loader.efi.canTouchEfiVariables = true;
    boot.loader.efi.efiSysMountPoint = "/boot";
    services.logind.lidSwitchExternalPower = "ignore";
    boot.loader.systemd-boot.enable = true;
  };
}
