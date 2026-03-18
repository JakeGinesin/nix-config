{
  config,
  pkgs,
  ...
}: {
  programs.home-manager.enable = true;

  imports = [
    ./alacritty/default.nix
    ./zsh/default.nix
    ./bspwm/default.nix
    ./cmus/default.nix
    # ./nitrogen/defualt.nix
    ./rofi/default.nix
    ./polybar/default.nix
    # wm stuff
    ./sxhkd/default.nix
    ./bspwm/default.nix

    ./xbindkeys/default.nix
    ./nvim/default.nix
    ./firefox/default.nix
    ./git/default.nix
    ./zathura/default.nix
    ./keepassxc/default.nix
    ./nf/default.nix
    ./beets/default.nix
    ./emacs/default.nix
    ./nnn/default.nix
  ];
}
