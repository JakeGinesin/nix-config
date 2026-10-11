{
  config,
  pkgs,
  ...
}: {
  services.dunst = {
    enable = true;
    # configFile = ./dunstrc;
    settings = {
      global = {
        monitor = 0;
        follow = "mouse";
        width = 300;
        height = 45;
        origin = "top-right";
        offset = "10x50";
        scale = 0;
        notification_limit = 0;
        progress_bar = true;
        progress_bar_height = 10;
        progress_bar_frame_width = 1;
        progress_bar_min_width = 150;
        progress_bar_max_width = 300;
        indicate_hidden = "yes";
        transparency = 0;
        separator_height = 2;
        padding = 8;
        horizontal_padding = 8;
        text_icon_padding = 0;
        frame_width = 1;
        frame_color = "#636363";
        separator_color = "frame";
        sort = "yes";
        font = "Monospace 8";
        line_height = 0;
        markup = "full";
        geometry = "300x2-30+20";
        shrink = "yes";
        format = "<b>%s</b>\n%b";
        alignment = "left";
        vertical_alignment = "center";
        show_age_threshold = 60;
        ellipsize = "middle";
        ignore_newline = "no";
        stack_duplicates = true;
        hide_duplicate_count = false;
        show_indicators = "yes";
        icon_position = "left";
        min_icon_size = 0;
        max_icon_size = 32;
        # icon_path = "/usr/share/icons/gnome/16x16/status/:/usr/share/icons/gnome/16x16/devices/";
        sticky_history = "yes";
        history_length = "20";
        title = "Dunst";
        class = "Dunst";
        corner_radius = 0;
        ignore_dbusclose = false;
        mouse_left_click = "close_current";
        mouse_middle_click = "do_action, close_current";
        mouse_right_click = "close_all";
      };

      experimental = {
        per_monitor_dpi = false;
      };

      urgency_low = {
        background = "#000000";
        foreground = "#EBDBB2";
        timeout = 3;
      };

      urgency_normal = {
        background = "#000000";
        foreground = "#EBDBB2";
        timeout = 3;
      };

      urgency_critical = {
        background = "#000000";
        foreground = "#EBDBB2";
        timeout = 3;
      };
    };
  };
}
