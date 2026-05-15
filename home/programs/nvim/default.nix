# ref: https://github.com/vimjoyer/nvim-nix-video/blob/main/home.nix
{
  pkgs,
  lib,
  ...
}: {
  programs.neovim = let
    toLua = str: "lua << EOF\n${str}\nEOF\n";
    toLuaFile = file: "lua << EOF\n${builtins.readFile file}\nEOF\n";
  in {
    enable = true;

    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    extraLuaConfig = ''
      ${builtins.readFile ./init.lua}
    '';

    extraPackages = with pkgs; [
      lua-language-server
      # rnix-lsp

      xclip
      wl-clipboard
      ripgrep
      fd
      lua-language-server
      rust-analyzer-unwrapped
      black
      nodejs_22
      latexrun
      tectonic
      texpresso
      # gh
    ];

    plugins = with pkgs.vimPlugins; [
      vim-nix
      vim-airline-themes
      plenary-nvim
      nvim-web-devicons
      texpresso-vim
      # {
      # plugin = smear-cursor-nvim;
      # config = toLuaFile ./plugins/smear.lua;
      # }
      # {
      # plugin = neovide;
      # config = toLuaFile ./plugins/neovide.lua;
      # }
      # { worthless plugin don't use
      # plugin = mini-animate;
      # config = toLuaFile ./plugins/mini-animate.lua;
      # }
      {
        plugin = telescope-nvim;
        config = toLuaFile ./plugins/telescope.lua;
      }
      {
        plugin = presenting-vim;
        config = toLuaFile ./plugins/presenting.lua;
      }
      # coc-nvim
      {
        plugin = vimtex;
        config = toLuaFile ./plugins/vimtex.lua;
      }
      {
        plugin = goyo-vim;
        config = toLuaFile ./plugins/goyo.lua;
      }
      {
        plugin = tokyonight-nvim;
        config = toLuaFile ./plugins/tokyonight.lua;
      }
      {
        plugin = nerdcommenter;
        config = toLuaFile ./plugins/nerdcommenter.lua;
      }
      {
        plugin = nvim-tree-lua;
        config = toLuaFile ./plugins/nvimtree.lua;
      }
      # {
      #   plugin = vim-airline;
      #   config = toLuaFile ./plugins/airline.lua;
      # }
      {
        plugin = markdown-preview-nvim;
        config = toLuaFile ./plugins/markdown-preview-nvim.lua;
      }
      {
        plugin = barbar-nvim;
        config = toLuaFile ./plugins/barbar.lua;
      }
      {
        # the most helpful thing is this guy: https://ejmastnak.com/tutorials/vim-latex/luasnip/
        plugin = luasnip;
        config = toLuaFile ./plugins/luasnip.lua;
      }
      {
        plugin = lualine-nvim;
        config = toLuaFile ./plugins/lualine.lua;
      }
      {
        plugin = nvim-treesitter.withPlugins (p: [
          # p.tree-sitter-nix
          # p.tree-sitter-vim
          # p.tree-sitter-bash
          # p.tree-sitter-lua
          # p.tree-sitter-python
          # p.tree-sitter-json
          p.bash
          p.comment
          p.css
          p.dockerfile
          p.fish
          p.gitattributes
          p.gitignore
          p.go
          p.gomod
          p.gowork
          p.hcl
          p.javascript
          p.jq
          p.json5
          p.json
          p.lua
          p.make
          p.markdown
          p.nix
          p.python
          p.rust
          p.toml
          p.typescript
          p.yaml
          p.agda
        ]);
        config = toLuaFile ./plugins/treesitter.lua;
      }
    ];

    # extraConfig = lib.fileContents ./init.vim;
  };

  # copy the snippets :#
  home.activation.copySnippetsDir = lib.mkAfter ''
    mkdir -p ~/.config/nvim/snippets
    cp -r ${./snippets}/* ~/.config/nvim/snippets/
    chmod -R u+w ~/.config/nvim/snippets/
  '';
}
