{
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../../system/system.nix
    ../meta.nix
  ];

  config = {
    networking.hostName = "rq"; # Define your hostname.
    res = "2560x1440";

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "backup";
      users.synchronous.imports = [../../home/home.nix];
    };

    boot.loader.grub.enable = true;
    boot.loader.grub.device = "/dev/nvme0n1";
    boot.loader.grub.useOSProber = true;
    boot.loader.grub.version = 2;
    services.logind.lidSwitchExternalPower = "ignore";

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
