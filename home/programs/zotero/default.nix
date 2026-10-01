{
  pkgs,
  lib,
  ...
}: let
  profile = "default";
  zroot = ".zotero/zotero";
  bbtVer = "7.0.76";
  bbt = pkgs.fetchurl {
    url = "https://github.com/retorquere/zotero-better-bibtex/releases/download/v${bbtVer}/zotero-better-bibtex-${bbtVer}.xpi";
    hash = "sha256-4MWwqSoOWPGiuLiZA6BfS24ScDdYhDto+jNF9l0C7kw=";
  };
in {
  # pin the profile dir name so it's identical on every machine
  home.file."${zroot}/profiles.ini" = {
    force = true;
    text = ''
      [Profile0]
      Name=default
      IsRelative=1
      Path=${profile}
      Default=1


      [General]
      StartWithLastProfile=1
      Version=2
    '';
  };

  home.file."${zroot}/${profile}/extensions/better-bibtex@iris-advies.com.xpi".source = bbt;

  home.file."${zroot}/${profile}/user.js".text = ''
    user_pref("extensions.zotero.dataDir", "/home/synchronous/zotero");
    user_pref("extensions.zotero.useDataDir", true);
    user_pref("extensions.zotero.sync.autoSync", true);
    user_pref("browser.theme.toolbar-theme", 0);
    user_pref("extensions.autoDisableScopes", 0);
    user_pref("extensions.zotero.export.quickCopy.setting", "export=9cb70025-a888-4a29-a210-93ec52da40d4");
  '';

  # merge any pre-existing random-named profile (e.g. oz1luut4.default) into the pinned one
  home.activation.zoteroMigrateProfile = lib.hm.dag.entryAfter ["linkGeneration"] ''
    zdir="$HOME/${zroot}"
    for old in "$zdir"/*/; do
      old="''${old%/}"
      name="$(basename "$old")"
      [ "$name" = "${profile}" ] && continue
      [ -f "$old/prefs.js" ] || continue
      if ${pkgs.curl}/bin/curl -s -m 1 http://127.0.0.1:23119/connector/ping >/dev/null; then
        echo "zotero: running, skipping migration of $name (close it and rebuild)"
        break
      fi
      run cp -r --update=none "$old/." "$zdir/${profile}/"
      run mv "$old" "$HOME/.zotero/backup-$name"
    done
  '';
}
