{
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../../system/system-server.nix
    ../meta.nix
    ../../extras/ssh.nix
    ../../extras/k3s-node.nix
  ];

  config = {
    networking.hostName = "store"; # Define your hostname.
    res = "1920x1080";

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "backup";
      users.synchronous.imports = [../../home/home.nix];
    };

    # Bootloader.
    #boot.loader.grub.enable = true;
    boot.loader.grub.device = "/dev/sda";
    boot.loader.grub.useOSProber = true;
    boot.loader.grub.version = 2;
    # services.logind.lidSwitchExternalPower = "ignore";

    boot.loader.systemd-boot.enable = false;
    boot.loader.efi.canTouchEfiVariables = true;
    boot.loader.grub.enable = true;
  };
}
