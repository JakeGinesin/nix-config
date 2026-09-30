{
  pkgs,
  lib,
  ...
}: let
  profile = "default";
  bbtVer = "7.0.76";
  bbt = pkgs.fetchurl {
    url = "https://github.com/retorquere/zotero-better-bibtex/releases/download/v${bbtVer}/zotero-better-bibtex-${bbtVer}.xpi";
    hash = "sha256-4MWwqSoOWPGiuLiZA6BfS24ScDdYhDto+jNF9l0C7kw=";
  };
in {
  home.file.".zotero/zotero/${profile}/extensions/better-bibtex@iris-advies.com.xpi".source = bbt;

  home.file.".zotero/zotero/${profile}/user.js".text = ''
    user_pref("extensions.zotero.dataDir", "/home/synchronous/zotero");
    user_pref("extensions.zotero.useDataDir", true);
    user_pref("extensions.zotero.sync.autoSync", true);
    user_pref("browser.theme.toolbar-theme", 0);

    // auto-enable sideloaded plugins
    user_pref("extensions.autoDisableScopes", 0);
    // Ctrl+Shift+C copies selected items as BibTeX
    user_pref("extensions.zotero.export.quickCopy.setting", "export=9cb70025-a888-4a29-a210-93ec52da40d4");
  '';
}
