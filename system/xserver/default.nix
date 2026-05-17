{
  config,
  pkgs,
  ...
}: {
  # services.xserver.dpi = 180;
  # services.dbus.enable = true;
  security.polkit.enable = true;

  services.xserver = {
    enable = true;
    xkb.layout = "us";
    xkb.variant = "";
    desktopManager.xterm.enable = false;
    windowManager.bspwm.enable = true;
  };

  services.displayManager = {
    defaultSession = "none+bspwm";
    # autoLogin.user = "synchronous";
    # autoLogin.enable = true;
    sddm.enable = true;
  };
}
