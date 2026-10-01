{
  pkgs,
  lib,
  ...
}: let
  bbtVer = "7.0.76";
  bbt = pkgs.fetchurl {
    url = "https://github.com/retorquere/zotero-better-bibtex/releases/download/v${bbtVer}/zotero-better-bibtex-${bbtVer}.xpi";
    hash = "sha256-4MWwqSoOWPGiuLiZA6BfS24ScDdYhDto+jNF9l0C7kw=";
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
in {
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
