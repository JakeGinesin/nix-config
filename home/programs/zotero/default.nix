{
  pkgs,
  lib,
  ...
}: let
  # zotero's build scripts edit firefox-esr-140's omni.ja by exact name, so it only builds against
  # esr-140. on unstable, esr-140 is marked broken (glibc 2.44, 2026-09-19) and then dropped
  # (2026-09-28), and zotero 10.0.4 vs esr-153 fails to build. take zotero from the nixos-26.05
  # channel instead: zotero 9.0.6 on esr-140.17 (channel head, so should be in the binary cache), and 9.x has the
  # /connector/saveStandaloneAttachment endpoint the 5.0.151 connector calls (7.0.x does not).
  # drop this pin once unstable's zotero builds again.
  zoteroNixpkgs =
    import (builtins.fetchTarball {
      url = "https://github.com/NixOS/nixpkgs/archive/6fcc160353f63555b560f25588925133c8f61f2a.tar.gz";
      sha256 = "sha256-xI8L+UwJLIg75yVJwLPsY+AUEP1teCT3FyuvodyJu2Y=";
    }) {
      inherit (pkgs.stdenv.hostPlatform) system;
    };
  zoteroPkg = zoteroNixpkgs.zotero;

  # 9.x line (7.0.76 was for zotero 7)
  bbtVer = "9.0.71";
  bbt = pkgs.fetchurl {
    url = "https://github.com/retorquere/zotero-better-bibtex/releases/download/v${bbtVer}/zotero-better-bibtex-${bbtVer}.xpi";
    hash = "sha256-v2GhaQ3IorerCb6d4siZhvT7bUlcgkB9ibECsm+6qdU=";
  };

  userJs = pkgs.writeText "zotero-user.js" ''
    user_pref("extensions.zotero.dataDir", "/home/synchronous/zotero");
    user_pref("extensions.zotero.useDataDir", true);
    user_pref("extensions.zotero.sync.autoSync", true);
    user_pref("browser.theme.toolbar-theme", 0);
    user_pref("extensions.autoDisableScopes", 0);
    user_pref("extensions.zotero.export.quickCopy.setting", "export=9cb70025-a888-4a29-a210-93ec52da40d4");
  '';

  # only used on a machine where Zotero has never run
  freshIni = pkgs.writeText "zotero-profiles.ini" ''
    [Profile0]
    Name=default
    IsRelative=1
    Path=default
    Default=1

    [General]
    StartWithLastProfile=1
    Version=2
  '';

  pgrep = "${pkgs.procps}/bin/pgrep";
  systemctl = "${pkgs.systemd}/bin/systemctl";
  unit = "zotero-background.service";

  # don't start (and fight over the profile lock) while a visible Zotero is open
  noGui = pkgs.writeShellScript "zotero-no-gui" ''
    ! ${pgrep} -u "$UID" -x zotero-bin >/dev/null
  '';

  # replaces `zotero`: swaps the background instance out for the GUI, then back in once it closes
  launcher = pkgs.writeShellScript "zotero" ''
    real=${zoteroPkg}/bin/zotero

    # a GUI is already open: just hand it the args (e.g. a zotero:// url)
    if ! ${systemctl} --user -q is-active ${unit} && ${pgrep} -u "$UID" -x zotero-bin >/dev/null; then
      exec "$real" "$@"
    fi

    ${systemctl} --user stop ${unit}
    "$real" "$@"
    ${systemctl} --user start ${unit}
  '';

  zotero = pkgs.symlinkJoin {
    name = "zotero-${zoteroPkg.version}";
    paths = [zoteroPkg];
    postBuild = ''
      rm $out/bin/zotero
      ln -s ${launcher} $out/bin/zotero
    '';
  };
in {
  home.packages = [zotero];

  # true --headless hangs connector saves (the item tree waits on a render that never happens),
  # so run on a private Xvfb display instead: nothing shows up on screen, ~0 cpu when idle
  systemd.user.services.zotero-background = {
    Unit = {
      Description = "Zotero on a private virtual display, for browser connector saves";
      PartOf = ["graphical-session.target"];
      After = ["graphical-session.target"];
    };
    Service = {
      ExecCondition = "${noGui}";
      ExecStart = "${pkgs.xvfb-run}/bin/xvfb-run -a -s '-screen 0 1280x800x24' ${zoteroPkg}/bin/zotero -no-remote";
      Restart = "on-failure";
      RestartSec = 10;
      TimeoutStopSec = 10;
      Nice = 19;
      CPUWeight = "idle";
      IOSchedulingClass = "idle";
    };
    Install.WantedBy = ["graphical-session.target"];
  };

  home.activation.zoteroProfile = lib.hm.dag.entryAfter ["linkGeneration"] ''
    zdir="$HOME/.zotero/zotero"
    ini="$zdir/profiles.ini"

    if [ ! -f "$ini" ]; then
      run mkdir -p "$zdir/default"
      run install -m 644 ${freshIni} "$ini"
    fi

    # resolve the Default=1 profile (fall back to the first one)
    prof="$(ZDIR="$zdir" ${pkgs.gawk}/bin/awk -F= '
      function flush() {
        if (p != "") {
          full = (rel == "0") ? p : ENVIRON["ZDIR"] "/" p
          if (first == "") first = full
          if (def && dflt == "") dflt = full
        }
        p = ""; rel = "1"; def = 0
      }
      /^\[/                        { flush(); next }
      $1 == "Path"                 { p = substr($0, 6) }
      $1 == "IsRelative"           { rel = $2 }
      $1 == "Default" && $2 == "1" { def = 1 }
      END { flush(); print (dflt != "" ? dflt : first) }
    ' "$ini")"

    if [ -z "$prof" ]; then
      echo "zotero: no profile found in $ini" >&2
    else
      run mkdir -p "$prof/extensions"
      run ln -sfn ${userJs} "$prof/user.js"
      run ln -sfn ${bbt} "$prof/extensions/better-bibtex@iris-advies.com.xpi"
    fi
  '';
}
