{
  pkgs,
  lib,
  osConfig,
  ...
}: let
  # same palette as polybar/config.ini (+ the colours its scripts hardcode)
  colors = {
    background = "#0d0d0d";
    foreground = "#ffffff";
    theme = "#89adfa";
    urgent = "#9b0a20";
    caps = "#FF7171";
    blue = "#2193ff"; # tailscale + bluetooth scripts
  };

  # nix strings have no \u escape, so round-trip through JSON. keeps this file
  # ascii and the codepoints greppable. all glyphs are from the Font Awesome block,
  # which both your v2 JetBrains Nerd Font ttf and nixpkgs' v3 one carry.
  glyph = hex: builtins.fromJSON ''"\u${hex}"'';

  # polybar look: icon in the theme colour, label in the foreground colour
  themed = s: "<span color='${colors.theme}'>${s}</span>  ";
  icon = hex: themed (glyph hex);

  # the hd / fhd / qhd blocks from polybar/default.nix
  dims =
    if osConfig.res == "1366x768"
    then {
      height = 20;
      font = 9;
      x = 2;
      y = 2;
      gap = 9;
    }
    else if osConfig.res == "2560x1440"
    then {
      height = 25;
      font = 11;
      x = 4;
      y = 3;
      gap = 12;
    }
    else {
      height = 20;
      font = 11;
      x = 4;
      y = 3;
      gap = 12;
    };

  niri = lib.getExe osConfig.programs.niri.package;
  jq = lib.getExe pkgs.jq;
  bin = "/etc/profiles/per-user/synchronous/bin";

  # polybar's bspwm module: only occupied desktops + the focused one, focused
  # underlined, urgent in red. your 20 named desktops show by name; niri's own
  # dynamic ones (e.g. an external monitor's) as output:index. event-driven off
  # niri's IPC stream, and only prints when the text changes (titles fire events too).
  workspaces = pkgs.writeShellScript "waybar-niri-workspaces" ''
    render() {
      ${niri} msg -j workspaces | ${jq} -c '
        def esc: gsub("&"; "&amp;") | gsub("<"; "&lt;") | gsub(">"; "&gt;");
        map(select(.is_focused or .active_window_id != null))
        | sort_by(.name == null, .output, .idx)
        | map((.name // "\(.output):\(.idx)" | esc) as $n
            | if .is_urgent then "<span background=\"${colors.urgent}\">  \($n)  </span>"
              elif .is_focused then "<span underline=\"single\" underline_color=\"${colors.theme}\">  \($n)  </span>"
              else "  \($n)  " end)
        | {text: join("")}'
    }

    prev=""
    ${niri} msg -j event-stream | while read -r _; do
      cur=$(render) || continue
      [ "$cur" = "$prev" ] && continue
      printf '%s\n' "$cur"
      prev=$cur
    done
  '';

  # polybar/scripts/tailscale.nix
  tailscale = pkgs.writeShellScript "waybar-tailscale" ''
    ip=$(/run/current-system/sw/bin/tailscale ip -4 2>/dev/null | head -n1)
    [ -n "$ip" ] || exit 0
    echo "<span color='${colors.blue}'>${glyph "2340"}</span>  [ts $ip]"
  '';

  # polybar's xkeyboard caps-lock indicator. reads the keyboard LEDs, which are
  # world-readable; waybar's keyboard-state module would need you in `input`
  # (i.e. able to read every keystroke on the machine)
  capslock = pkgs.writeShellScript "waybar-capslock" ''
    for led in /sys/class/leds/*::capslock/brightness; do
      if [ -r "$led" ] && [ "$(cat "$led")" != 0 ]; then
        echo "<span color='${colors.caps}'>${glyph "f023"}  caps lock</span>"
        exit 0
      fi
    done
  '';
in {
  config = lib.mkIf osConfig.programs.niri.enable {
    programs.waybar = {
      enable = true;
      # hm's unit is WantedBy graphical-session.target with
      # ConditionEnvironment=WAYLAND_DISPLAY, so it only ever comes up under niri
      systemd.enable = true;

      settings.mainBar = {
        layer = "top";
        position = "top";
        height = dims.height;
        margin-top = dims.y;
        margin-left = dims.x;
        margin-right = dims.x;
        spacing = dims.gap; # polybar module-margin-left = 3

        modules-left = [
          "clock"
          "battery"
          "cpu"
          "memory"
          "temperature"
          "pulseaudio"
          "network"
          "custom/tailscale"
          "disk"
          "custom/nix-store"
          "bluetooth"
          "custom/cmus"
        ];
        modules-center = ["niri/window"];
        modules-right = [
          "custom/pomodoro"
          "custom/capslock"
          "custom/workspaces"
          "tray"
        ];

        clock = {
          format = "{:%H:%M}";
          interval = 60;
          tooltip = false;
        };

        battery = {
          bat = "BAT0";
          adapter = "AC0";
          full-at = 99;
          interval = 10;
          format = "${themed "{icon}"}{capacity}%";
          format-charging = "${icon "f0e7"}{capacity}%";
          format-full = "${icon "f240"}100%";
          format-icons = map glyph ["f244" "f243" "f242" "f241" "f240"];
          tooltip = false;
        };

        cpu = {
          interval = 4;
          format = "${icon "f4bc"}{usage}%";
          tooltip = false;
        };

        memory = {
          interval = 4;
          format = "${icon "f2db"}{percentage}%";
          tooltip = false;
        };

        temperature = {
          hwmon-path = "/sys/class/hwmon/hwmon1/temp1_input";
          critical-threshold = 90;
          interval = 5;
          format = "${icon "f2c9"}{temperatureC}${glyph "00b0"}C";
          format-critical = "${icon "f2c9"}<span color='${colors.urgent}'>{temperatureC}${glyph "00b0"}C</span>";
          tooltip = false;
        };

        pulseaudio = {
          format = "${icon "f028"}{volume}%";
          format-muted = "${icon "f026"}{volume}%";
          tooltip = false;
        };

        network = {
          interface = "wlan0";
          interval = 4;
          format-wifi = "${icon "f1eb"}{bandwidthDownBytes} [{essid}]";
          format-disconnected = "${icon "f1eb"}disconnected";
          tooltip = false;
        };

        "custom/tailscale" = {
          exec = "${tailscale}";
          interval = 15;
          tooltip = false;
        };

        disk = {
          path = "/";
          interval = 100;
          format = "${icon "f0a0"}{percentage_used}%";
          tooltip = false;
        };

        "custom/nix-store" = {
          exec = "sh ${bin}/nix-store-usage 2>/dev/null";
          interval = 100;
          format = "${icon "f313"}{}";
          tooltip = false;
        };

        bluetooth = {
          format = "<span color='${colors.blue}'>${glyph "f294"}</span>";
          format-connected = "<span color='${colors.blue}'>${glyph "f294"}</span>  [{device_alias}]";
          format-off = "";
          format-disabled = "";
          format-no-controller = "";
          tooltip = false;
        };

        "custom/cmus" = {
          exec = "sh ${bin}/cmus-status 2>/dev/null | rg -v 'NO_MUSIC'";
          interval = 6;
          escape = true; # song titles with & or < would break pango otherwise
          format = "<span color='${colors.theme}'>${glyph "266b"}</span>  {}";
          tooltip = false;
        };

        "niri/window" = {
          format = "{title}";
          max-length = 50;
          tooltip = false;
        };

        "custom/pomodoro" = {
          exec = "sh ${bin}/pomodoro";
          interval = 5;
          tooltip = false;
        };

        "custom/capslock" = {
          exec = "${capslock}";
          interval = 1;
          tooltip = false;
        };

        "custom/workspaces" = {
          exec = "${workspaces}";
          return-type = "json";
          restart-interval = 2;
          tooltip = false;
        };

        tray.spacing = 8;
      };

      style = ''
        * {
          font-family: "Noto Sans", "JetBrainsMono Nerd Font", "Noto Sans Symbols";
          font-size: ${toString dims.font}pt;
          border: none;
          border-radius: 0;
          min-height: 0;
          box-shadow: none;
          text-shadow: none;
        }

        window#waybar {
          background: ${colors.background};
          color: ${colors.foreground};
        }

        /* polybar padding-left/right = 2 */
        .modules-left { margin-left: ${toString dims.gap}px; }
        .modules-right { margin-right: ${toString dims.gap}px; }

        /* polybar title: format-padding = 4 */
        #window { padding: 0 ${toString (dims.gap * 2)}px; }
      '';
    };
  };
}
