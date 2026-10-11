{
  config,
  pkgs,
  ...
}: {
  services.picom = {
    enable = true;
    shadow = false;
    fade = false;
    activeOpacity = 1.0;
    inactiveOpacity = 1.0; # yeah, i'm a freak like that
    backend = "xrender"; # can use "glx"
  };

  systemd.user.services.picom.Unit.ConditionEnvironment = "!WAYLAND_DISPLAY";
}
