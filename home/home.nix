{
  config,
  pkgs,
  lib,
  ...
}: let
  myPerl = pkgs.perl.withPackages (ps:
    with ps; [
      perl
      NetDNS
      NetIP
      NetNetmask
      StringRandom
      XMLWriter
      NetWhoisIP
      WWWMechanize
    ]);

  myDnsenum =
    pkgs.runCommand "dnsenum-wrapped" {
      nativeBuildInputs = [pkgs.makeWrapper];
    } ''
      mkdir -p $out/bin
      makeWrapper ${pkgs.dnsenum}/bin/dnsenum $out/bin/dnsenum \
        --set PERL5LIB ${myPerl}/lib/perl5/site_perl
    '';
in {
  # home.packages = builtins.attrValues scriptDerivations;

  home.username = "synchronous";
  home.homeDirectory = "/home/synchronous";
  imports = [
    ./programs/programs.nix
    ./services/services.nix
    ./wallpapers/default.nix
    ./fonts/default.nix # need to manage fonts in two places becuase life sucks nix sucks
  ];

  # home.activation.copyScripts = lib.mkAfter ''
  # mkdir -p ~/.scripts
  # cp ${./nixos-rebuild.sh} ~/.scripts/
  # chmod -R u+w ~/.scripts/
  # '';

  home.stateVersion = "24.11"; # Please read the comment before changing.

  # age.secrets.zsh_remote.file = ../secrets/zsh_remote.age;
  # age.secretsDir = "/home/synchronous/.agenix/agenix";
  # age.secretsMountPoint = "/home/synchronous/.agenix/agenix.d";
  # age.identityPaths = ["/home/synchronous/.ssh/id_ed25519"];

  # home.packages = with pkgs; [xrandr procps polybar bspwm sxhkd polybar-pulseaudio-control bluez];

  home.sessionVariables = {
    EDITOR = "nvim";
    SHELL = "zsh";
    HOME = "/home/synchronous";
    # XDG_CACHE_HOME = "$HOME/.cache";
    DBUS_SESSION_BUS_ADDRESS = "unix:path=$XDG_RUNTIME_DIR/bus";
  };

  programs.home-manager.enable = true;

  home.packages = with pkgs;
    [
      systemd
      cachix
      # any other packages go here
      # xrandr
      xorg.xrandr
      bspwm
      yt-dlp
      beets
      netcat
      zathura
      keepassxc
      sshpass
      mpv
      jellyfin-ffmpeg
      simple-mtpfs
      signal-desktop
      slack
      nodejs_24
      gnumake
      choose # better awk and cut
      grc
      go
      calibre
      gcc
      vscode
      code-cursor
      cloc
      gnome-pomodoro
      zip
      unzip
      jq
      btop
      wikiman
      iodine
      fzf
      lsof
      ldns
      cmatrix
      pipes-rs
      # gimp (doens't werk)
      file
      feh
      ncdu
      clisp
      libsForQt5.qt5.qttools
      bc # for qdbus + bc for pomodoro script
      # rocmPackages.llvm.clang-unwrapped
      # direnv
      # emacs # haha
      ripgrep-all
      element-desktop
      rustup # for verus rip
      python313Packages.ipython
      sage
      yq
      semgrep
      # texlive.combined.scheme-full

      # security
      aflplusplus
      wget
      traceroute
      dig
      httpx
      sshfs
      katana
      eyewitness
      masscan
      dnsx
      amass
      myDnsenum
      whois
      macchanger
      aircrack-ng
      dhcpcd
      wireshark
      postman
      nuclei
      subfinder
    ]
    ++ (
      with lib; let
        # this function extracts the base file name from a path.
        basename = path: lib.lists.last (lib.strings.splitString "/" (toString path));

        files = lib.filesystem.listFilesRecursive ./scripts;
      in
        # for each script found, create a derivation installed in $PATH
        lib.lists.forEach files (
          file: let
            scriptName = strings.removeSuffix ".sh" (basename file);
          in
            pkgs.writeScriptBin
            # (basename file) # the new package's name
            scriptName
            (builtins.readFile file)
        )
    );

  # home.file.".profile".text = ''
  # if [ -f "$HOME/.scripts/res.sh" ]; then
  # . "$HOME/.scripts/res.sh"
  # fi
  # '';
}
