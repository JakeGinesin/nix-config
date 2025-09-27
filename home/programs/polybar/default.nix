{
  config,
  pkgs,
  lib,
  osConfig,
  ...
}: let
  mypolybar = pkgs.polybar.override {
    alsaSupport = true;
    githubSupport = true;
    mpdSupport = true;
    pulseSupport = true;
  };

  colors = {
    background = "#0d0d0d";
    foreground = "#ffffff";
    theme = "#89adfa";
  };

  bluetoothScript = pkgs.callPackage ./scripts/bluetooth.nix {};

  bctl = ''
    [module/bluetooth]
    type = custom/script
    interval = 10
    exec = ${bluetoothScript}/bin/bluetooth-ctl
    label-foreground = ${colors.foreground}
    format-foreground = ${colors.theme}
  '';

  tailscaleScript = pkgs.callPackage ./scripts/tailscale.nix {};
  tctl = ''
    [module/tailscale]
    type = custom/script
    interval = 15
    exec = ${tailscaleScript}/bin/tailscale-ctl
    label-foreground = ${colors.foreground}
    format-foreground = ${colors.theme}
  '';

  ip = "/run/current-system/sw/bin/ip";
  grep = "/run/current-system/sw/bin/grep";
  awk = "/run/current-system/sw/bin/awk";

  pctl = ''
    [module/pomodoro]
    type = custom/script
    tail = true
    interval = 5
    format = <label>
    exec = "sh /etc/profiles/per-user/synchronous/bin/pomodoro"
    label-foreground = ${colors.foreground}
    format-foreground = ${colors.theme}
  '';

  cmusctl = ''
    [module/cmus]
    type = custom/script
    tail = true
    format =♫  <label>
    interval = 5
    exec-if = "sh /etc/profiles/per-user/synchronous/bin/cmus-status 2> /dev/null | rg -v 'NO_MUSIC'"
    exec = "sh /etc/profiles/per-user/synchronous/bin/cmus-status 2> /dev/null | rg -v 'NO_MUSIC'"
    label-foreground = ${colors.foreground}
    format-foreground = ${colors.theme}
  '';

  # networkingDevice = builtins.exec "ip route | grep default | awk '{print $5}'";
  # networkingDevice = pkgs.runCommand "get-network-device" {} ''
  # ${ip} route | ${grep} default | ${awk} '{print $5}' > $out
  # '';

  hd = ''
    [bar/mybar]
    height = 20
    font-0 = "NotoSans-Regular:size=9;2.5"
    font-1 = "JetBrainsMono Nerd Font:style=Regular:size=9;2.5"
    font-2 = "Noto Sans Symbols:size=9;1"
    offset-x = 2
    offset-y = 2
  '';

  fhd = ''
    [bar/mybar]
    height = 20
    font-0 = "NotoSans-Regular:size=11;2.5"
    font-1 = "JetBrainsMono Nerd Font:style=Regular:size=11;2.5"
    font-2 = "Noto Sans Symbols:size=11;1"
    offset-x = 4
    offset-y = 3
  '';

  qhd = ''
    [bar/mybar]
    height = 25
    font-0 = "NotoSans-Regular:size=11;2.5"
    font-1 = "JetBrainsMono Nerd Font:style=Regular:size=11;2.5"
    font-2 = "Noto Sans Symbols:size=13;1"
    offset-x = 4
    offset-y = 3
  '';

  mon =
    if osConfig.res == "1366x768"
    then hd
    else if osConfig.res == "2560x1440"
    then qhd
    else fhd;

  internets = ''
    [module/network]
    type = internal/network
    interface = wlan0
    interval = 4.0
    udspeed-minwidth = 5
    accumulate-stats = true
    unknown-as-up = true

    format-connected = 直<label-connected>
    format-connected-foreground = ${colors.theme}
    label-connected = %downspeed% [%essid%]
    label-connected-foreground = ${colors.foreground}

    format-disconnected = 睊  <label-disconnected>
    format-disconnected-foreground = ${colors.theme}
    label-disconnected = disconnected
    label-disconnected-foreground = ${colors.foreground}
  '';
in {
  services.polybar = {
    enable = true;
    package = mypolybar;
    config = ./config.ini;
    extraConfig = bctl + internets + mon + tctl + pctl + cmusctl;
    # my savior: https://www.reddit.com/r/NixOS/comments/v8ikwq/polybar_doesnt_start_at_launch/
    script = ''
      # echo "none"
      polybar mybar 2> /dev/null & disown
      # setsid polybar mybar > /dev/null 2> /dev/null &> /dev/null
    '';
  };

  # home.activation.polybarStartup = lib.hm.dag.entryAfter ["writeBoundary"] ''
  #   exec /etc/profiles/per-user/synchronous/bin/polybar -c /home/synchronous/.config/polybar/config.ini mybar & disown
  # '';

  home.activation.polybarRestart = lib.hm.dag.entryAfter ["writeBoundary"] ''
    /etc/profiles/per-user/synchronous/bin/systemctl --user restart polybar
  '';

  systemd.user.services.polybar = {
    Install.WantedBy = ["graphical-session.target"];
  };

  # home.activation.copyPolybarScriptsDir = lib.mkAfter ''
  # mkdir -p ~/.config/polybar/scripts
  # cp -r ${./scripts}/* ~/.config/polybar/scripts
  # chmod -R +x ~/.config/polybar/scripts
  # '';
}
