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

  programs.nnn.plugins.src = ./preview-tui;
}
