{
  config,
  pkgs,
  lib,
  isServer,
  ...
}: {
  imports =
    [
      ./synaptics/default.nix
      ./tailscale/default.nix
    ]
    ++ lib.optionals (!isServer) [
      ./syncthing/default.nix
      ./dnsmasq/default.nix
      ./printing.nix
      ./remote-builds.nix
    ];
}
