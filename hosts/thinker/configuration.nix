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
    ../../extras/ssh.nix
  ];

  config = {
    networking.hostName = "thinker"; # Define your hostname.
    res = "1920x1080";

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "backup";
      users.synchronous.imports = [../../home/home.nix];
    };

    # Bootloader.
    # boot.loader.grub.enable = true;
    # boot.loader.grub.device = "/dev/nvme0n1";
    # boot.loader.grub.useOSProber = true;
    # services.logind.lidSwitchExternalPower = "ignore";

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    boot.loader.grub.enable = false;
    boot.kernelModules = ["mt7921e"];
  };
}
