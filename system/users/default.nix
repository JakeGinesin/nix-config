{
  config,
  pkgs,
  ...
}: let
  pkg_with_working_nitrogen = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/c0c50dfcb70d48e5b79c4ae9f1aa9d339af860b4.tar.gz";
    sha256 = "17p3w4mgfr4yj2p0jz6kqgzhyr04h4fap5hnd837664xd1xhwdjb";
  }) {inherit (pkgs) system;};

  old-nitrogen = pkg_with_working_nitrogen.nitrogen;
in {
  users.users.synchronous = {
    isNormalUser = true;
    description = "jake";
    extraGroups = ["networkmanager" "wheel" "docker" "syncthing"];
    packages = with pkgs; [
      # kdePackages.kate
      # firefox
      git
      arandr
      procs
      htop
      zsh
      ripgrep
      rofi
      alacritty
      python3
      tree
      old-nitrogen
      polybar
      sxhkd
      bspwm
      # librewolf
      eza
      flameshot
      neofetch
      lolcat
      nnn
      xclip
      brightnessctl
      xbindkeys
      pulseaudio
      xorg.xf86inputsynaptics
      libnotify # for notify-send
      alejandra
      discord
      legcord
      polybar-pulseaudio-control
      bluez # polybar
      zotero
      texliveFull
      texlivePackages.latexmk
      nmap
      procps # for pgrep
      # xorg.xrandr
      #  thunderbird
    ];
  };

  environment.systemPackages = with pkgs; [
    vim
    neovim
    linux-manual
    man-pages
    man-pages-posix
    fontconfig
    python3
    rofi
    flameshot
    tree
    # nitrogen
    polybar
    sxhkd
    bspwm
    # linuxKernel.packages.linux_zen.rtl8812au
    # librewolf
  ];
}
