{
  config,
  pkgs,
  lib,
  ...
}: {
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

    # zsh_remote = lib.mkOption {
    # type = lib.types.str;
    # default = "1920x1080";
    # description = "zsh remote secret";
    # };
  };

  config = {
    networking.hostName = "rq"; # Define your hostname.
    res = "2560x1440";

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "backup";
      users.synchronous.imports = [../../home/home.nix];
    };

    # Bootloader.
    boot.loader.grub.enable = true;
    boot.loader.grub.device = "/dev/nvme0n1";
    boot.loader.grub.useOSProber = true;
    boot.loader.grub.version = 2;
    services.logind.lidSwitchExternalPower = "ignore";

    age = {
      secrets.zsh_remote = {
        file = ../../secrets/zsh_remote.age;
        owner = "synchronous";
        mode = "0400";
      };
      tailscale-rq = {
        file = ../../secrets/tailscale-rq.age;
        owner = "synchronous";
        mode = "0400";
      };
      secretsDir = "/home/synchronous/.agenix/agenix";
      secretsMountPoint = "/home/synchronous/.agenix/agenix.d";
      identityPaths = ["/home/synchronous/.ssh/id_ed25519"];
    };

    #boot = {
    #  loader.systemd-boot = {
    #    enable = true;
    #    editor = false;
    #  };
    #  kernelPackages = pkgs.linuxPackages;
    #};
    # boot.loader.systemd-boot.enable = true;
    # boot.loader.efi.canTouchEfiVariables = true;
    # boot.loader.grub.enable = false;
  };
}
