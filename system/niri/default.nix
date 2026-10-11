{
  config,
  pkgs,
  lib,
  isServer,
  ...
}: {
  # niri shows up as a second session in sddm on every non-server host; bspwm stays
  # the default because xserver/default.nix sets defaultSession explicitly (niri's
  # module only mkDefaults it). user-side config lives in home/programs/{niri,waybar}
  config = lib.mkIf (!isServer) {
    # installs niri, its sddm session, the systemd units, gnome+gtk portals, swaylock pam
    programs.niri.enable = true;

    # niri runs X11 clients (zotero, anything old) through xwayland-satellite,
    # spawned on demand as long as it's on PATH
    environment.systemPackages = [pkgs.xwayland-satellite];

    # electron (signal, slack, element, legcord) goes native wayland under niri and
    # stays X11 under bspwm; the flag is just --ozone-platform-hint=auto
    environment.sessionVariables.NIXOS_OZONE_WL = "1";

    # programs.niri mkDefaults gnome-keyring on. you're on keepassxc + gpg-agent,
    # and gcr's ssh agent would fight gpg-agent over SSH_AUTH_SOCK
    services.gnome.gnome-keyring.enable = false;

    # niri's module also turns this on, which would start ~/.config/autostart
    # entries in the bspwm session too. niri runs them itself via its own unit
    services.xserver.desktopManager.runXdgAutostartIfNone = false;
  };
}
