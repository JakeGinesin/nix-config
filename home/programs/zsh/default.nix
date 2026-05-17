{
  pkgs,
  lib,
  system,
  config,
  osConfig,
  ...
}: {
  home.packages = with pkgs; [zsh-powerlevel10k meslo-lgs-nf];
  home.file.".p10k.zsh".source = ./p10k;
  programs.direnv.enable = true;

  programs.zsh = {
    enable = true;
    # dotDir = "$HOME/.config/zsh";

    plugins = [
      {
        name = "zsh-powerlevel10k";
        src = "${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/";
        file = "powerlevel10k.zsh-theme";
      }
      {
        name = "powerlevel10k-config";
        src = lib.cleanSource ./p10k;
        file = "p10k.zsh";
      }
    ];

    oh-my-zsh = {
      enable = true;
      # theme = "af-magic";
      # theme = "powerlevel10k/powerlevel10k";
      plugins = ["git" "history-substring-search" "colored-man-pages"];
    };

    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    # recall agenix secrets cannot be used at eval time, so we must do this trash
    # like what the fuck? I spent 4 hours figuring this out. will i ever reach nix nirvana?
    initContent = lib.mkMerge [
      (lib.mkBefore ''
        [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
      '')
      ''
        ${builtins.readFile ./zshrc}
        if [ -f "${osConfig.age.secrets.zsh_remote.path}" ]; then
          source "${osConfig.age.secrets.zsh_remote.path}"
        fi
      ''
    ];
  };
}
