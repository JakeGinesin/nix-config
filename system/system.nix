{
  config,
  pkgs,
  ...
}: {
  imports = [
    # ./wm/bspwm.nix
    ./xserver/default.nix
    ./services/services.nix
    ./fonts/fonts.nix
    ./hardware/hardware.nix
    ./networking/default.nix
    ./users/default.nix
  ];

  # Set your time zone.
  time.timeZone = "America/New_York";
  # time.timeZone = "Asia/Seoul";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  nixpkgs.config.allowUnfree = true;

  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    liveRestore = false;
  };

  programs.nix-ld.enable = true;

  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;
  services.udisks2.enable = true;
  services.printing.enable = true;
  hardware.bluetooth.enable = true;
  programs.dconf.enable = true;
  services.pcscd.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  xdg.mime.defaultApplications = {
    "application/pdf" = "firefox.desktop";
    "text/html" = "firefox.desktop";
    "text/markdown" = "firefox.desktop";
    "text/x-markdown" = "firefox.desktop";
    "x-scheme-handler/about" = "firefox.desktop";
    "x-scheme-handler/http" = "firefox.desktop";
    "x-scheme-handler/https" = "firefox.desktop";
    "x-scheme-handler/unknown" = "firefox.desktop";
  };

  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  security.sudo = {
    # me ne frego. i dare you to privilege escalate me
    enable = true;
    extraRules = [
      {
        commands = [
          {
            command = "/etc/profiles/per-user/synchronous/bin/rebuild";
            options = ["NOPASSWD"];
          }
          {
            command = "/home/synchronous/nix-cfg/home/scripts/nixos-rebuild.sh";
            options = ["NOPASSWD"];
          }
          {
            command = "/home/synchronous/.scripts/nixos-rebuild.sh";
            options = ["NOPASSWD"];
          }
          {
            # are you serious?
            command = "/run/current-system/sw/bin/nixos-rebuild";
            options = ["NOPASSWD"];
          }
        ];
        users = ["synchronous"];
      }
    ];
  };

  virtualisation.docker.extraOptions = ''
    --insecure-registry 100.125.181.75:5000
  '';

  # programs.direnv.enable = true;

  nix = {
    nixPath = [
      "nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos"
      "nixos-config=/home/synchronous/nix-cfg/configuration.nix"
      "/nix/var/nix/profiles/per-user/root/channels"
    ];

    settings = {
      experimental-features = ["nix-command" "flakes"];
      substituters = [
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };
  };

  boot.extraModulePackages = with config.boot.kernelPackages; [
    rtl88xxau-aircrack
  ];

  boot.kernelModules = ["rtl8812au"];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
