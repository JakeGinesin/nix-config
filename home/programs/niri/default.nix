{
  pkgs,
  lib,
  osConfig,
  ...
}: let
  niri = osConfig.programs.niri.package;

  # same raw-file workflow as sxhkdrc, but `niri validate` runs at build time, so a
  # typo fails the rebuild instead of niri quietly keeping its previous config
  checkedConfig = pkgs.runCommandLocal "niri-config.kdl" {} ''
    ${lib.getExe niri} validate -c ${./config.kdl}
    cp ${./config.kdl} $out
  '';
in {
  config = lib.mkIf osConfig.programs.niri.enable {
    # niri watches this path and hot-reloads when a rebuild swaps the symlink
    xdg.configFile."niri/config.kdl".source = checkedConfig;

    home.packages = with pkgs; [
      swaybg # niri-wallpaper (home/scripts/niri)
      wl-clipboard # wl-copy/wl-paste; xclip still works through xwayland-satellite
    ];

    # Ctrl+Alt+Delete; pam entry comes from programs.niri on the system side
    programs.swaylock = {
      enable = true;
      settings = {
        color = "0d0d0d";
        indicator-idle-visible = false;
        show-failed-attempts = true;
        inside-color = "0d0d0d";
        ring-color = "89adfa";
        key-hl-color = "ffffff";
        line-color = "00000000";
        separator-color = "00000000";
      };
    };
  };
}
