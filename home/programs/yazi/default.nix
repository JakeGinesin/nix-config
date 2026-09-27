{
  builtins,
  lib,
  ...
}: let
  c = {
    bg = "#0d0d0d";
    fg = "#e3e1e1";
    black = "#080808";
    grey = "#303030";
    bgHl = "#292e42";
    gutter = "#3b4261";
    comment = "#565f89";
    lightblue = "#737aa2";
    blue = "#7aa2f7";
    cyan = "#7dcfff";
    teal = "#73daca";
    green = "#9ece6a";
    yellow = "#e0af68";
    orange = "#ff9e64";
    red = "#f7768e";
    deepred = "#c53b53";
    magenta = "#bb9af7";
    violet = "#d183e8";
  };

  bubble = {
    open = "";
    close = "";
  };

  border = {fg = c.blue;};
in {
  programs.yazi = {
    enable = true;

    theme = {
      mgr = {
        cwd = {
          fg = c.cyan;
          bold = true;
        };
        hovered = {
          fg = c.fg;
          bg = c.bgHl;
          bold = true;
        };
        preview_hovered = {underline = true;};
        find_keyword = {
          fg = c.orange;
          bold = true;
          underline = true;
        };
        find_position = {
          fg = c.magenta;
          bold = true;
        };
        symlink_target = {
          fg = c.teal;
          italic = true;
        };

        marker_copied = {
          fg = c.green;
          bg = c.green;
        };
        marker_cut = {
          fg = c.red;
          bg = c.red;
        };
        marker_marked = {
          fg = c.cyan;
          bg = c.cyan;
        };
        marker_selected = {
          fg = c.yellow;
          bg = c.yellow;
        };

        count_copied = {
          fg = c.black;
          bg = c.green;
        };
        count_cut = {
          fg = c.black;
          bg = c.red;
        };
        count_selected = {
          fg = c.black;
          bg = c.yellow;
        };

        border_symbol = "│";
        border_style = {fg = c.gutter;};
      };

      tabs = {
        active = {
          fg = c.black;
          bg = c.lightblue;
          bold = true;
        };
        inactive = {
          fg = c.fg;
          bg = c.grey;
        };
        sep_inner = bubble;
        sep_outer = bubble;
      };

      # mirrors lualine: normal = lightblue, visual/select = deepred, unset = violet
      mode = {
        normal_main = {
          fg = c.black;
          bg = c.lightblue;
          bold = true;
        };
        normal_alt = {
          fg = c.fg;
          bg = c.grey;
        };
        select_main = {
          fg = c.black;
          bg = c.deepred;
          bold = true;
        };
        select_alt = {
          fg = c.fg;
          bg = c.grey;
        };
        unset_main = {
          fg = c.black;
          bg = c.violet;
          bold = true;
        };
        unset_alt = {
          fg = c.fg;
          bg = c.grey;
        };
      };

      status = {
        overall = {};
        sep_left = bubble;
        sep_right = bubble;

        perm_sep = {fg = c.comment;};
        perm_type = {fg = c.green;};
        perm_read = {fg = c.yellow;};
        perm_write = {fg = c.red;};
        perm_exec = {fg = c.cyan;};

        progress_label = {
          fg = c.fg;
          bold = true;
        };
        progress_normal = {
          fg = c.blue;
          bg = c.grey;
        };
        progress_error = {
          fg = c.red;
          bg = c.grey;
        };
      };

      which = {
        mask = {bg = c.bg;};
        cand = {fg = c.cyan;};
        rest = {fg = c.comment;};
        desc = {fg = c.magenta;};
        separator = "  ";
        separator_style = {fg = c.gutter;};
      };

      confirm = {
        inherit border;
        title = border;
        btn_yes = {
          fg = c.black;
          bg = c.blue;
        };
        btn_no = {};
      };

      spot = {
        inherit border;
        title = border;
        tbl_col = {fg = c.blue;};
        tbl_cell = {
          fg = c.black;
          bg = c.yellow;
        };
      };

      notify = {
        title_info = {fg = c.green;};
        title_warn = {fg = c.yellow;};
        title_error = {fg = c.red;};
      };

      pick = {
        inherit border;
        active = {
          fg = c.magenta;
          bold = true;
        };
        inactive = {};
      };

      input = {
        inherit border;
        title = {};
        value = {};
        selected = {bg = c.bgHl;};
      };

      cmp = {
        inherit border;
        active = {bg = c.bgHl;};
        inactive = {};
      };

      tasks = {
        inherit border;
        title = {};
        hovered = {
          fg = c.magenta;
          underline = true;
        };
      };

      help = {
        on = {fg = c.cyan;};
        run = {fg = c.magenta;};
        desc = {fg = c.fg;};
        hovered = {
          bg = c.bgHl;
          bold = true;
        };
        footer = {
          fg = c.black;
          bg = c.lightblue;
        };
      };

      filetype.rules = [
        {
          mime = "image/*";
          fg = c.yellow;
        }
        {
          mime = "{audio,video}/*";
          fg = c.magenta;
        }
        {
          mime = "application/{zip,rar,7z*,tar,gzip,xz,zstd,bzip*,lzma,compress,archive,cpio,arj,xar,ms-cab*}";
          fg = c.red;
        }
        {
          mime = "application/{pdf,doc,rtf}";
          fg = c.cyan;
        }
        {
          url = "*";
          is = "orphan";
          fg = c.deepred;
        }
        {
          url = "*";
          is = "exec";
          fg = c.green;
        }
        {
          url = "*/";
          fg = c.blue;
        }
        {
          url = "*";
          fg = c.fg;
        }
      ];
    };
  };
}
