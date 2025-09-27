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
    ../meta.nix
  ];

  config = {
    networking.hostName = "yoga"; # Define your hostname.
    res = "1920x1080";

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "backup";
      users.synchronous.imports = [../../home/home.nix];
    };

    boot.loader.efi.canTouchEfiVariables = true;
    boot.loader.efi.efiSysMountPoint = "/boot";
    services.logind.lidSwitchExternalPower = "ignore";
    boot.loader.systemd-boot.enable = true;
  };
}
