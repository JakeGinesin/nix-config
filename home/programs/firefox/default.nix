{
  pkgs,
  lib,
  osConfig,
  ...
}: let
  # osConfig carries config from configuration.nix
  scale =
    if osConfig.res == "1366x768"
    then 0.80
    else if osConfig.res == "2560x1440"
    then 1.25
    else 1.00;
in {
  home.activation.copyStartpage = lib.mkAfter ''
    mkdir -p ~/.firefox-startpage
    cp -r ${./startpage}/* ~/.firefox-startpage/
    chmod -R u+w ~/.firefox-startpage/
  '';

  programs.firefox = {
    enable = true;
    # https://discourse.nixos.org/t/declare-firefox-extensions-and-settings/36265
    # https://mozilla.github.io/policy-templates/#extensionsettings
    policies = {
      ExtensionSettings = {
        # "*".installation_mode = "blocked"; # blocks all addons except the ones specified below
        # uBlock Origin:
        "uBlock0@raymondhill.net" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
          installation_mode = "force_installed";
          default_area = "menupanel";
        };
        "jid1-MnnxcxisBPnSXQ@jetpack" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/privacy-badger17/latest.xpi";
          installation_mode = "force_installed";
          default_area = "menupanel";
        };
        "addon@darkreader.org" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/darkreader/latest.xpi";
          installation_mode = "force_installed";
          default_area = "menupanel";
        };
        "dfyoutube@example.com" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/file/3449086/df_youtube-1.13.504.xpi";
          installation_mode = "force_installed";
          default_area = "menupanel";
        };
        "zotero@chnm.gmu.edu" = {
          install_url = "https://www.zotero.org/download/connector/dl?browser=firefox&version=5.0.151";
          installation_mode = "force_installed";
          default_area = "navbar";
        };
      };
    };
    profiles.synchronous = {
      # extensions = with inputs.firefox-addons.packages.${pkgs.system}; [
      # ublock-origin
      # stylus
      # ];
      # extensions = [
      # ublock-origin
      # ];
      userChrome = ''
        /* Hide window control buttons */
        #titlebar-min, #titlebar-max, #titlebar-close {
          display: none !important;
        }

        .titlebar-buttonbox-container{
          display:none;
        }

        /* https://www.reddit.com/r/FirefoxCSS/comments/1igbt7c/comment/mangluv/ */
        /* hide top right gap */
        .titlebar-spacer[type="post-tabs"] {
          display: none !important
        }
      '';
      bookmarks = {
        force = true;
        settings = [
          {
            name = "Bar";
            toolbar = true;
            bookmarks = [
              {
                name = "nixos";
                bookmarks = [
                  {
                    name = "noogle";
                    url = "https://noogle.dev/";
                  }
                  {
                    name = "home manager options";
                    url = "https://home-manager-options.extranix.com/";
                  }
                  {
                    name = "nixpkgs";
                    url = "https://search.nixos.org/packages";
                  }
                  {
                    name = "dots";
                    url = "https://github.com/JakeGinesin/nix-dots";
                  }
                  {
                    name = "nix options";
                    url = "https://search.nixos.org/options";
                  }
                  {
                    name = "old packages";
                    url = "https://lazamar.co.uk/nix-versions/";
                  }
                ];
              }
              {
                name = "cmu";
                bookmarks = [
                  {
                    name = "computing facilities";
                    url = "https://computing.cs.cmu.edu/landing/student";
                  }
                  {
                    name = "csd phd resources";
                    url = "https://www.cs.cmu.edu/~csd-grad/";
                  }
                  {
                    name = "general phd resources";
                    url = "https://csd.cmu.edu/academics/doctoral-resources";
                  }
                  # {
                  # name = "cmu orders";
                  # url = "https://rams.srv.cs.cmu.edu/ords/";
                  # }
                  {
                    name = "cmu sio";
                    url = "https://s3.andrew.cmu.edu/sio";
                  }
                  {
                    name = "husker";
                    url = "https://www.husker.nu";
                  }
                  {
                    name = "mit library experts";
                    url = "https://libraries.mit.edu/experts/";
                  }
                  {
                    name = "cmu canvas";
                    url = "https://canvas.cmu.edu/";
                  }
                  {
                    name = "cmu email";
                    url = "https://email.cmu.edu";
                  }
                  {
                    name = "grfp";
                    url = "https://www.research.gov/grfp/Login.do"; # your tax dollars fund my phd loser. pay big sam up.
                  }
                  {
                    name = "cmueats";
                    url = "https://cmueats.com/";
                  }
                  {
                    name = "cmucourses";
                    url = "https://cmucourses.com/";
                  }
                ];
              }
              {
                name = "solvers";
                bookmarks = [
                  {
                    name = "GPT";
                    url = "https://chatgpt.com"; # sam altman is a horrible person and i cannot wait for the day i can ditch this shit
                  }
                  {
                    name = "claude";
                    url = "https://claude.ai";
                  }
                  {
                    name = "gemini";
                    url = "https://gemini.google.com";
                  }
                ];
              }
              {
                name = "verus";
                bookmarks = [
                  {
                    name = "verus playground";
                    url = "https://play.verus-lang.org/?version=stable&mode=basic&edition=2021";
                  }
                  {
                    name = "verus docs";
                    url = "https://verus-lang.github.io/verus/guide/verus_macro_intro.html";
                  }
                  {
                    name = "verus zulip";
                    url = "https://verus-lang.zulipchat.com/#feed";
                  }
                  {
                    name = "vstd docs";
                    url = "https://verus-lang.github.io/verus/verusdoc/vstd/index.html";
                  }
                  {
                    name = "core docs";
                    url = "https://doc.rust-lang.org/1.88.0/core/index.html";
                  }
                  {
                    name = "verus github";
                    url = "https://github.com/verus-lang/verus";
                  }
                  {
                    name = "secure foundations";
                    url = "https://github.com/secure-foundations";
                  }
                ];
              }
              {
                name = "cal";
                url = "https://calendar.google.com/";
              }
              {
                name = "performance";
                url = "about:processes";
              }
            ];
          }
        ];
      };
      settings = {
        ### This is all aesthetic stuff
        # for tiling window managers expands to the size of the window

        # tighten dns cache expiration since we have local cache (dnsmasq) declared
        "network.dnsCacheExpiration" = "0";

        # QUIC
        "network.http.http3.enabled" = true;
        "network.http.http3.grease-advertised-version" = true;
        "browser.sessionstore.restore_on_demand" = true;
        "dom.ipc.processPriorityManager.idleUsesNanoStackshot" = true;

        "dom.ipc.processPriorityManager.backgroundUsesEcoQoS" = false;

        # disable prefetch
        "network.prefetch-next" = false;
        "network.dns.disablePrefetch" = true;
        "network.dns.disablePrefetchFromHTTPS" = true;
        "network.predictor.enable-prefetch" = false;
        "network.http.speculative-parallel-limit" = 0;

        # dir lol
        "browser.download.dir" = "/home/synchronous/downloads";
        "browser.download.folderList" = 2;

        "browser.cache.memory.enable" = false;
        "browser.tabs.unloadOnLowMemory" = true;
        "accessibility.force_disabled" = 1;
        "gfx.webrender.all" = true;
        "gfx.webrender.software" = false;

        # disable zoom with ctrl+mouse, https://support.mozilla.org/en-US/questions/1253302
        "mousewheel.with_control.action" = 1;

        # should change this based on your resolution
        "layout.css.devPixelsPerPx" = scale;

        "extensions.activeThemeID" = "firefox-compact-dark@mozilla.org";
        "full-screen-api.ignore-widgets" = true;

        # tab open behavior
        "browser.search.openintab" = true;
        "browser.search.suggest.enabled" = false; # fuck you search, wikipedia is my default.

        # fuck you, searching in the URL bar should only touch my bookmarks
        # (can control + g to get to google anyways)
        "browser.urlbar.suggest.topsites" = false;
        "browser.urlbar.suggest.searches" = false;
        "browser.urlbar.suggest.history" = false;
        "browser.urlbar.suggest.engines" = false;
        "browser.urlbar.suggest.openpage" = false;
        "browser.urlbar.suggest.bookmark" = true;
        "browser.link.open_newwindow" = 3;
        "browser.link.open_newwindow.restriction" = 0;

        # extensions
        "extensions.ublock-origin.enabled" = true;
        # "extensions.stylus.enabled" = true;
        # "extensions.pocket.enabled" = false;

        # imprermanance stuffs
        "browser.download.panel.shown" = true;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
        "browser.aboutwelcome.enabled" = false;
        "browser.startup.homepage" = "file:///home/synchronous/.firefox-startpage/index.html";

        ### Everything below is a Security minded config setting
        # Default to dark theme in DevTools panel
        "devtools.theme" = "dark";
        # Enable ETP for decent security (makes firefox containers and many
        # common security/privacy add-ons redundant).
        "browser.contentblocking.category" = "strict";
        "privacy.donottrackheader.enabled" = true;
        "privacy.donottrackheader.value" = 1;
        "privacy.purge_trackers.enabled" = true;
        # Your customized toolbar settings are stored in
        # 'browser.uiCustomization.state'. This tells firefox to sync it between
        # machines. WARNING: This may not work across OSes. Since I use NixOS on
        # all the machines I use Firefox on, this is no concern to me.
        #"services.sync.prefs.sync.browser.uiCustomization.state" = true;
        # Enable userContent.css and userChrome.css for our theme modules
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        # Stop creating ~/Downloads!
        #"browser.download.dir" = "${config.user.home}/downloads";
        # Don't use the built-in password manager. A nixos user is more likely
        # using an external one (you are using one, right?).
        "signon.rememberSignons" = false;
        # Do not check if Firefox is the default browser
        "browser.shell.checkDefaultBrowser" = false;
        # Disable the "new tab page" feature and show a blank tab instead
        # https://wiki.mozilla.org/Privacy/Reviews/New_Tab
        # https://support.mozilla.org/en-US/kb/new-tab-page-show-hide-and-customize-top-sites#w_how-do-i-turn-the-new-tab-page-off
        "browser.newtabpage.enabled" = false;
        "browser.newtab.url" = "about:blank";
        # Disable Activity Stream
        # https://wiki.mozilla.org/Firefox/Activity_Stream
        "browser.newtabpage.activity-stream.enabled" = false;
        "browser.newtabpage.activity-stream.telemetry" = false;
        # Disable new tab tile ads & preload
        # http://www.thewindowsclub.com/disable-remove-ad-tiles-from-firefox
        # http://forums.mozillazine.org/viewtopic.php?p=13876331#p13876331
        # https://wiki.mozilla.org/Tiles/Technical_Documentation#Ping
        # https://gecko.readthedocs.org/en/latest/browser/browser/DirectoryLinksProvider.html#browser-newtabpage-directory-source
        # https://gecko.readthedocs.org/en/latest/browser/browser/DirectoryLinksProvider.html#browser-newtabpage-directory-ping
        "browser.newtabpage.enhanced" = false;
        "browser.newtabpage.introShown" = true;
        "browser.newtab.preload" = false;
        "browser.newtabpage.directory.ping" = "";
        "browser.newtabpage.directory.source" = "data:text/plain,{}";
        # Reduce search engine noise in the urlbar's completion window. The
        # shortcuts and suggestions will still work, but Firefox won't clutter
        # its UI with reminders that they exist.
        #"browser.urlbar.suggest.searches" = false;
        #"browser.urlbar.shortcuts.bookmarks" = false;
        #"browser.urlbar.shortcuts.history" = false;
        #"browser.urlbar.shortcuts.tabs" = false;
        #"browser.urlbar.showSearchSuggestionsFirst" = false;
        #"browser.urlbar.speculativeConnect.enabled" = false;
        # https://bugzilla.mozilla.org/1642623
        "browser.urlbar.dnsResolveSingleWordsAfterSearch" = 0;
        # https://blog.mozilla.org/data/2021/09/15/data-and-firefox-suggest/
        "browser.urlbar.suggest.quicksuggest.nonsponsored" = false;
        "browser.urlbar.suggest.quicksuggest.sponsored" = false;
        # Show whole URL in address bar
        "browser.urlbar.trimURLs" = false;
        # Disable some not so useful functionality.
        "browser.disableResetPrompt" = true; # "Looks like you haven't started Firefox in a while."
        "browser.onboarding.enabled" = false; # "New to Firefox? Let's get started!" tour
        "browser.aboutConfig.showWarning" = false; # Warning when opening about:config
        "media.videocontrols.picture-in-picture.video-toggle.enabled" = false;
        "reader.parse-on-load.enabled" = false; # "reader view"

        # Security-oriented defaults
        "security.family_safety.mode" = 0;
        # https://blog.mozilla.org/security/2016/10/18/phasing-out-sha-1-on-the-public-web/
        "security.pki.sha1_enforcement_level" = 1;
        # https://github.com/tlswg/tls13-spec/issues/1001
        "security.tls.enable_0rtt_data" = false;
        # Use Mozilla geolocation service instead of Google if given permission
        #"geo.provider.network.url" = "https://location.services.mozilla.com/v1/geolocate?key=%MOZILLA_API_KEY%";
        #"geo.provider.use_gpsd" = false;
        # https://support.mozilla.org/en-US/kb/extension-recommendations
        "browser.newtabpage.activity-stream.asrouter.userprefs.cfr" = false;
        "browser.newtabpage.activity-stream.asrouter.userprefs.cfr.addons" = false;
        "browser.newtabpage.activity-stream.asrouter.userprefs.cfr.features" = false;
        "extensions.htmlaboutaddons.recommendations.enabled" = false;
        "extensions.htmlaboutaddons.discover.enabled" = false;
        "extensions.getAddons.showPane" = false; # uses Google Analytics
        "browser.discovery.enabled" = false;
        # Reduce File IO / SSD abuse
        # Otherwise, Firefox bombards the HD with writes. Not so nice for SSDs.
        # This forces it to write every 30 minutes, rather than 15 seconds.
        "browser.sessionstore.interval" = "1800000";
        # Disable battery API
        # https://developer.mozilla.org/en-US/docs/Web/API/BatteryManager
        # https://bugzilla.mozilla.org/show_bug.cgi?id=1313580
        "dom.battery.enabled" = false;
        # Disable "beacon" asynchronous HTTP transfers (used for analytics)
        # https://developer.mozilla.org/en-US/docs/Web/API/navigator.sendBeacon
        "beacon.enabled" = false;
        # Disable pinging URIs specified in HTML <a> ping= attributes
        # http://kb.mozillazine.org/Browser.send_pings
        "browser.send_pings" = false;
        # Disable gamepad API to prevent USB device enumeration
        # https://www.w3.org/TR/gamepad/
        # https://trac.torproject.org/projects/tor/ticket/13023
        "dom.gamepad.enabled" = false;
        # Don't try to guess domain names when entering an invalid domain name in URL bar
        # http://www-archive.mozilla.org/docs/end-user/domain-guessing.html
        "browser.fixup.alternate.enabled" = false;
        # Disable telemetry
        # https://wiki.mozilla.org/Platform/Features/Telemetry
        # https://wiki.mozilla.org/Privacy/Reviews/Telemetry
        # https://wiki.mozilla.org/Telemetry
        # https://www.mozilla.org/en-US/legal/privacy/firefox.html#telemetry
        # https://support.mozilla.org/t5/Firefox-crashes/Mozilla-Crash-Reporter/ta-p/1715
        # https://wiki.mozilla.org/Security/Reviews/Firefox6/ReviewNotes/telemetry
        # https://gecko.readthedocs.io/en/latest/browser/experiments/experiments/manifest.html
        # https://wiki.mozilla.org/Telemetry/Experiments
        # https://support.mozilla.org/en-US/questions/1197144
        # https://firefox-source-docs.mozilla.org/toolkit/components/telemetry/telemetry/internals/preferences.html#id1
        "toolkit.telemetry.unified" = false;
        "toolkit.telemetry.enabled" = false;
        "toolkit.telemetry.server" = "data:,";
        "toolkit.telemetry.archive.enabled" = false;
        "toolkit.telemetry.coverage.opt-out" = true;
        "toolkit.coverage.opt-out" = true;
        "toolkit.coverage.endpoint.base" = "";
        "experiments.supported" = false;
        "experiments.enabled" = false;
        "experiments.manifest.uri" = "";
        "browser.ping-centre.telemetry" = false;
        # https://mozilla.github.io/normandy/
        "app.normandy.enabled" = false;
        "app.normandy.api_url" = "";
        "app.shield.optoutstudies.enabled" = false;
        # Disable health reports (basically more telemetry)
        # https://support.mozilla.org/en-US/kb/firefox-health-report-understand-your-browser-perf
        # https://gecko.readthedocs.org/en/latest/toolkit/components/telemetry/telemetry/preferences.html
        "datareporting.healthreport.uploadEnabled" = false;
        "datareporting.healthreport.service.enabled" = false;
        "datareporting.policy.dataSubmissionEnabled" = false;

        # Disable crash reports
        "breakpad.reportURL" = "";
        "browser.tabs.crashReporting.sendReport" = false;
        "browser.crashReports.unsubmittedCheck.autoSubmit2" = false; # don't submit backlogged reports

        # Disable Form autofill
        # https://wiki.mozilla.org/Firefox/Features/Form_Autofill
        "browser.formfill.enable" = false;
        "extensions.formautofill.addresses.enabled" = false;
        "extensions.formautofill.available" = "off";
        "extensions.formautofill.creditCards.available" = false;
        "extensions.formautofill.creditCards.enabled" = false;
        "extensions.formautofill.heuristics.enabled" = false;

        # disable attributes
        # https://blog.zgp.org/turn-off-advertising-features-in-firefox/
        "dom.private-attribution.submission.enabled" = false;

        # compact mode
        "browser.compactmode.show" = true;
      };
    };
  };
  programs.librewolf = {
    enable = false; # sorry
    settings = {
      "app.update.auto" = false;
      # "browser.startup.homepage" = "https://lobste.rs";
      "extensions.activeThemeID" = "firefox-compact-dark@mozilla.org";
      # "browser.urlbar.placeholderName" = "Wikipedia";
      # "browser.urlbar.suggest.history" = "false";
      # "privacy.resistFingerprinting" = "false";
      "full-screen-api.ignore-widgets" = true;

      # tab open behavior
      "browser.search.openintab" = true;
      "browser.link.open_newwindow" = 3;
      "browser.link.open_newwindow.restriction" = 0;

      # extensions
      "extensions.ublock-origin.enabled" = true;
      "extensions.stylus.enabled" = true;
      "extensions.pocket.enabled" = false;

      # imprermanance stuffs
      "browser.download.panel.shown" = true;
      "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
      "browser.aboutwelcome.enabled" = false;
      "browser.startup.homepage" = "about:blank";

      ### Everything below is a Security minded config setting
      # Default to dark theme in DevTools panel
      "devtools.theme" = "dark";
      # Enable ETP for decent security (makes firefox containers and many
      # common security/privacy add-ons redundant).
      "browser.contentblocking.category" = "strict";
      "privacy.donottrackheader.enabled" = true;
      "privacy.donottrackheader.value" = 1;
      "privacy.purge_trackers.enabled" = true;
      # Your customized toolbar settings are stored in
      # 'browser.uiCustomization.state'. This tells firefox to sync it between
      # machines. WARNING: This may not work across OSes. Since I use NixOS on
      # all the machines I use Firefox on, this is no concern to me.
      #"services.sync.prefs.sync.browser.uiCustomization.state" = true;
      # Enable userContent.css and userChrome.css for our theme modules
      "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
      # Stop creating ~/Downloads!
      #"browser.download.dir" = "${config.user.home}/downloads";
      # Don't use the built-in password manager. A nixos user is more likely
      # using an external one (you are using one, right?).
      "signon.rememberSignons" = false;
      # Do not check if Firefox is the default browser
      "browser.shell.checkDefaultBrowser" = false;
      # Disable the "new tab page" feature and show a blank tab instead
      # https://wiki.mozilla.org/Privacy/Reviews/New_Tab
      # https://support.mozilla.org/en-US/kb/new-tab-page-show-hide-and-customize-top-sites#w_how-do-i-turn-the-new-tab-page-off
      "browser.newtabpage.enabled" = false;
      "browser.newtab.url" = "about:blank";
      # Disable Activity Stream
      # https://wiki.mozilla.org/Firefox/Activity_Stream
      "browser.newtabpage.activity-stream.enabled" = false;
      "browser.newtabpage.activity-stream.telemetry" = false;
      # Disable new tab tile ads & preload
      # http://www.thewindowsclub.com/disable-remove-ad-tiles-from-firefox
      # http://forums.mozillazine.org/viewtopic.php?p=13876331#p13876331
      # https://wiki.mozilla.org/Tiles/Technical_Documentation#Ping
      # https://gecko.readthedocs.org/en/latest/browser/browser/DirectoryLinksProvider.html#browser-newtabpage-directory-source
      # https://gecko.readthedocs.org/en/latest/browser/browser/DirectoryLinksProvider.html#browser-newtabpage-directory-ping
      "browser.newtabpage.enhanced" = false;
      "browser.newtabpage.introShown" = true;
      "browser.newtab.preload" = false;
      "browser.newtabpage.directory.ping" = "";
      "browser.newtabpage.directory.source" = "data:text/plain,{}";
      # Reduce search engine noise in the urlbar's completion window. The
      # shortcuts and suggestions will still work, but Firefox won't clutter
      # its UI with reminders that they exist.
      #"browser.urlbar.suggest.searches" = false;
      #"browser.urlbar.shortcuts.bookmarks" = false;
      #"browser.urlbar.shortcuts.history" = false;
      #"browser.urlbar.shortcuts.tabs" = false;
      #"browser.urlbar.showSearchSuggestionsFirst" = false;
      #"browser.urlbar.speculativeConnect.enabled" = false;
      # https://bugzilla.mozilla.org/1642623
      "browser.urlbar.dnsResolveSingleWordsAfterSearch" = 0;
      # https://blog.mozilla.org/data/2021/09/15/data-and-firefox-suggest/
      "browser.urlbar.suggest.quicksuggest.nonsponsored" = false;
      "browser.urlbar.suggest.quicksuggest.sponsored" = false;
      # Show whole URL in address bar
      "browser.urlbar.trimURLs" = false;
      # Disable some not so useful functionality.
      "browser.disableResetPrompt" = true; # "Looks like you haven't started Firefox in a while."
      "browser.onboarding.enabled" = false; # "New to Firefox? Let's get started!" tour
      "browser.aboutConfig.showWarning" = false; # Warning when opening about:config
      "media.videocontrols.picture-in-picture.video-toggle.enabled" = false;
      "reader.parse-on-load.enabled" = false; # "reader view"

      # Security-oriented defaults
      "security.family_safety.mode" = 0;
      # https://blog.mozilla.org/security/2016/10/18/phasing-out-sha-1-on-the-public-web/
      "security.pki.sha1_enforcement_level" = 1;
      # https://github.com/tlswg/tls13-spec/issues/1001
      "security.tls.enable_0rtt_data" = false;
      # Use Mozilla geolocation service instead of Google if given permission
      #"geo.provider.network.url" = "https://location.services.mozilla.com/v1/geolocate?key=%MOZILLA_API_KEY%";
      #"geo.provider.use_gpsd" = false;
      # https://support.mozilla.org/en-US/kb/extension-recommendations
      "browser.newtabpage.activity-stream.asrouter.userprefs.cfr" = false;
      "browser.newtabpage.activity-stream.asrouter.userprefs.cfr.addons" = false;
      "browser.newtabpage.activity-stream.asrouter.userprefs.cfr.features" = false;
      "extensions.htmlaboutaddons.recommendations.enabled" = false;
      "extensions.htmlaboutaddons.discover.enabled" = false;
      "extensions.getAddons.showPane" = false; # uses Google Analytics
      "browser.discovery.enabled" = false;
      # Reduce File IO / SSD abuse
      # Otherwise, Firefox bombards the HD with writes. Not so nice for SSDs.
      # This forces it to write every 30 minutes, rather than 15 seconds.
      "browser.sessionstore.interval" = "1800000";
      # Disable battery API
      # https://developer.mozilla.org/en-US/docs/Web/API/BatteryManager
      # https://bugzilla.mozilla.org/show_bug.cgi?id=1313580
      "dom.battery.enabled" = false;
      # Disable "beacon" asynchronous HTTP transfers (used for analytics)
      # https://developer.mozilla.org/en-US/docs/Web/API/navigator.sendBeacon
      "beacon.enabled" = false;
      # Disable pinging URIs specified in HTML <a> ping= attributes
      # http://kb.mozillazine.org/Browser.send_pings
      "browser.send_pings" = false;
      # Disable gamepad API to prevent USB device enumeration
      # https://www.w3.org/TR/gamepad/
      # https://trac.torproject.org/projects/tor/ticket/13023
      "dom.gamepad.enabled" = false;
      # Don't try to guess domain names when entering an invalid domain name in URL bar
      # http://www-archive.mozilla.org/docs/end-user/domain-guessing.html
      "browser.fixup.alternate.enabled" = false;
      # Disable telemetry
      # https://wiki.mozilla.org/Platform/Features/Telemetry
      # https://wiki.mozilla.org/Privacy/Reviews/Telemetry
      # https://wiki.mozilla.org/Telemetry
      # https://www.mozilla.org/en-US/legal/privacy/firefox.html#telemetry
      # https://support.mozilla.org/t5/Firefox-crashes/Mozilla-Crash-Reporter/ta-p/1715
      # https://wiki.mozilla.org/Security/Reviews/Firefox6/ReviewNotes/telemetry
      # https://gecko.readthedocs.io/en/latest/browser/experiments/experiments/manifest.html
      # https://wiki.mozilla.org/Telemetry/Experiments
      # https://support.mozilla.org/en-US/questions/1197144
      # https://firefox-source-docs.mozilla.org/toolkit/components/telemetry/telemetry/internals/preferences.html#id1
      "toolkit.telemetry.unified" = false;
      "toolkit.telemetry.enabled" = false;
      "toolkit.telemetry.server" = "data:,";
      "toolkit.telemetry.archive.enabled" = false;
      "toolkit.telemetry.coverage.opt-out" = true;
      "toolkit.coverage.opt-out" = true;
      "toolkit.coverage.endpoint.base" = "";
      "experiments.supported" = false;
      "experiments.enabled" = false;
      "experiments.manifest.uri" = "";
      "browser.ping-centre.telemetry" = false;
      # https://mozilla.github.io/normandy/
      "app.normandy.enabled" = false;
      "app.normandy.api_url" = "";
      "app.shield.optoutstudies.enabled" = false;
      # Disable health reports (basically more telemetry)
      # https://support.mozilla.org/en-US/kb/firefox-health-report-understand-your-browser-perf
      # https://gecko.readthedocs.org/en/latest/toolkit/components/telemetry/telemetry/preferences.html
      "datareporting.healthreport.uploadEnabled" = false;
      "datareporting.healthreport.service.enabled" = false;
      "datareporting.policy.dataSubmissionEnabled" = false;

      # Disable crash reports
      "breakpad.reportURL" = "";
      "browser.tabs.crashReporting.sendReport" = false;
      "browser.crashReports.unsubmittedCheck.autoSubmit2" = false; # don't submit backlogged reports

      # Disable Form autofill
      # https://wiki.mozilla.org/Firefox/Features/Form_Autofill
      "browser.formfill.enable" = false;
      "extensions.formautofill.addresses.enabled" = false;
      "extensions.formautofill.available" = "off";
      "extensions.formautofill.creditCards.available" = false;
      "extensions.formautofill.creditCards.enabled" = false;
      "extensions.formautofill.heuristics.enabled" = false;
    };
  };
}
