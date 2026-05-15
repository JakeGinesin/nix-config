{
  builtins,
  lib,
  ...
}: {
  programs.nnn = {
    enable = true;
  };

  home.sessionVariables = {
    NNN_OPENER = "nvim";
    NNN_PLUG = "m:preview-tui;";
    NNN_FIFO = "/tmp/nnn.fifo";
    NNN_TERMINAL = "alacritty";
  };

  home.activation.nnnPlugins = lib.hm.dag.entryAfter ["writeBoundary"] ''
    mkdir -p $HOME/.config/nnn/plugins
    cp --no-preserve=mode ${./preview-tui} $HOME/.config/nnn/plugins/preview-tui
    chmod +x $HOME/.config/nnn/plugins/preview-tui
  '';

  # programs.nnn.plugins.src = ./nnn-plugins;
}
