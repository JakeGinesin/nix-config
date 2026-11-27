# local AI server: Ollama (Vulkan) for chat models, managed entirely from Open WebUI; SearXNG
# web search; stable-diffusion.cpp behind llama-swap for image generation; sandboxed code/terminal
# execution (docker); and a sandboxed coding-agent container.
#
# everything that listens beyond loopback is only opened on the tailscale interface.
#
#   http://<tailscaleAddress>/        open webui (first account created becomes admin).
#                                     models: admin panel -> settings -> models -> pull
#                                     (ollama.com names like `gpt-oss:120b`, or `hf.co/<user>/<repo>:<quant>`)
#   http://<tailscaleAddress>:11434   ollama API (OpenAI- and Anthropic-compatible too)
#   http://<tailscaleAddress>:9292    llama-swap (image model) + /ui
#   http://<tailscaleAddress>:8890    searxng
#   http://<tailscaleAddress>:8188    comfyui (if enabled)
#   ssh -p 2222 coder@<tailscaleAddress>   coding sandbox (if enabled)
#
# secrets (webui session key, searx key, jupyter token, open-terminal key) are generated on
# first boot into /var/lib/ai-secrets, so nothing has to be agenix'd by hand.
{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.ai;
  inherit (lib) mkOption mkEnableOption mkIf types;

  secretsDir = "/var/lib/ai-secrets";
  modelsDir = "/var/lib/ai-models"; # image weights (fetched by ai-model-fetch) and comfyui

  ports = {
    webui = 8080; # loopback, fronted by nginx on :80
    llamaSwap = 9292;
    ollama = 11434;
    searx = 8890;
    jupyter = 8888; # loopback
    terminal = 8000; # loopback
    comfyui = 8188; # nginx on the tailnet
    comfyuiLocal = 18188; # loopback
  };
  ollamaUrl = "http://127.0.0.1:${toString ports.ollama}";
  ctx = toString cfg.ollama.contextLength;

  # vulkan (RADV) is the most stable and usually the fastest backend on gfx1151
  sdCpp = pkgs.stable-diffusion-cpp-vulkan; # ships sd-server (its meta.mainProgram is stale)

  # llama-swap substitutes ${PORT} itself, so it is kept literal here
  imageCmd = id: m:
    "${sdCpp}/bin/sd-server --listen-ip 127.0.0.1 --listen-port \${PORT} "
    + lib.escapeShellArgs (
      lib.concatLists (lib.mapAttrsToList (flag: url: ["--${flag}" "${modelsDir}/${id}/${baseNameOf url}"]) m.files)
      ++ m.args
    );

  imageModels = lib.optionalAttrs cfg.images.enable (lib.mapAttrs (id: m: {
      inherit (m) name ttl;
      cmd = imageCmd id m;
      checkEndpoint = "/v1/models";
      unlisted = true; # keeps it out of open webui's chat model list
    })
    cfg.images.models);
  imagesOn = imageModels != {};

  # every file the image models need, fetched at runtime (no hashes to maintain for multi-GB blobs)
  imageFiles = lib.concatLists (lib.mapAttrsToList (id: m:
    lib.mapAttrsToList (_: url: {
      dir = "${modelsDir}/${id}";
      inherit url;
    })
    m.files)
  cfg.images.models);

  # open webui's terminal integration; the key is spliced in at runtime by ai-secrets
  terminalConnections = builtins.toJSON [
    {
      id = "open-terminal";
      name = "Sandbox terminal";
      enabled = true;
      url = "http://127.0.0.1:${toString ports.terminal}";
      key = "@TERMINAL_KEY@";
      auth_type = "bearer";
      config.access_grants = []; # empty = admins only
    }
  ];

  secretConsumers =
    ["open-webui.service" "searx-init.service" "searx.service"]
    ++ lib.optionals cfg.sandbox.enable ["docker-open-terminal.service" "docker-jupyter.service"];

  imageModule = types.submodule ({name, ...}: {
    options = {
      name = mkOption {
        type = types.str;
        default = name;
      };
      files = mkOption {
        type = types.attrsOf types.str;
        description = "sd-server flag -> download URL; each file is passed as --<flag> <local path>";
        example = {
          diffusion-model = "https://huggingface.co/.../model.safetensors";
          vae = "https://huggingface.co/.../ae.safetensors";
        };
      };
      ttl = mkOption {
        type = types.int;
        default = 900;
      };
      args = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "extra sd-server arguments (sampler defaults, offloading, ...)";
      };
    };
  });
in {
  options.ai = {
    enable = mkEnableOption "the local AI stack";

    tailscaleAddress = mkOption {
      type = types.str;
      description = "tailnet address the web UI is reached at (used for WEBUI_URL)";
    };

    interface = mkOption {
      type = types.str;
      default = config.services.tailscale.interfaceName;
      description = "the only interface the AI services are reachable on";
    };

    huggingfaceTokenFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "/run/agenix/hf-token";
      description = "file containing `HF_TOKEN=hf_...`, if an image model's weights are gated";
    };

    ollama = {
      models = mkOption {
        type = types.listOf types.str;
        default = [];
        description = ''
          models to always have pulled. optional: normally you pull and delete models from
          open webui's admin panel, and those are kept (nothing here removes them).
        '';
      };
      contextLength = mkOption {
        type = types.int;
        default = 131072;
        description = ''
          default context window for every model. ollama silently truncates prompts beyond it, and
          coding agents want at least ~64k. per-model overrides live in open webui's model settings.
        '';
      };
    };

    embeddingModel = mkOption {
      type = types.str;
      default = "qwen3-embedding:0.6b";
      description = "ollama embedding model open webui uses for RAG (pulled automatically)";
    };

    images = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "image generation through stable-diffusion.cpp's sd-server (behind llama-swap)";
      };
      default = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "image model id open webui generates with";
      };
      size = mkOption {
        type = types.str;
        default = "1024x1024";
      };
      steps = mkOption {
        type = types.int;
        default = 8;
      };
      models = mkOption {
        type = types.attrsOf imageModule;
        default = {};
      };
    };

    sandbox.enable = mkOption {
      type = types.bool;
      default = true;
      description = "docker-sandboxed Open Terminal (shell tool) and Jupyter (code interpreter)";
    };

    coding = {
      enable = mkEnableOption ''
        a sandboxed coding box: a NixOS container with claude code, opencode, codex and aider,
        pointed at ollama, reachable with `ssh -p <sshPort> coder@<tailscaleAddress>`
      '';
      model = mkOption {
        type = types.str;
        default = "qwen3-coder-next";
        description = "ollama model the agents default to (pulled automatically)";
      };
      sshPort = mkOption {
        type = types.port;
        default = 2222;
      };
      authorizedKeys = mkOption {
        type = types.listOf types.str;
        default = config.users.users.synchronous.openssh.authorizedKeys.keys;
        defaultText = lib.literalExpression "config.users.users.synchronous.openssh.authorizedKeys.keys";
      };
      memoryMax = mkOption {
        type = types.str;
        default = "32G";
        description = "memory cap for everything running in the sandbox";
      };
    };

    comfyui.enable = mkEnableOption "ComfyUI (ROCm container) for node-based image/video workflows";

    tailscaleServe = mkEnableOption ''
      `tailscale serve` HTTPS in front of open webui (https://<host>.<tailnet>.ts.net), which
      browsers need for microphone/voice input. requires HTTPS certificates to be enabled in the
      tailnet admin console
    '';
  };

  config = mkIf cfg.enable {
    hardware.graphics.enable = true;

    environment.systemPackages = [
      config.services.ollama.package # `ollama ps`, `ollama pull ...`
      pkgs.amdgpu_top
      pkgs.nvtopPackages.amd
      pkgs.vulkan-tools
    ];

    ##
    ## chat models: ollama. pull/delete from open webui; it loads models on demand and unloads
    ## idle ones (keep-alive), evicting the least recently used when memory runs short.
    ##

    services.ollama = {
      enable = true;
      package = pkgs.ollama-vulkan;
      host = "0.0.0.0"; # firewall only admits the tailnet
      port = ports.ollama;
      loadModels = lib.unique ([cfg.embeddingModel] ++ cfg.ollama.models ++ lib.optional cfg.coding.enable cfg.coding.model);
      environmentVariables = {
        OLLAMA_VULKAN = "1";
        # ollama discards integrated GPUs on vulkan unless told otherwise (only CUDA iGPUs and ROCm
        # gfx1151 are allowed by default), which silently runs everything on the CPU. the log says
        # "dropping integrated GPU; to enable, set OLLAMA_IGPU_ENABLE=1"
        OLLAMA_IGPU_ENABLE = "1";
        OLLAMA_FLASH_ATTENTION = "1";
        OLLAMA_KV_CACHE_TYPE = "q8_0"; # halves context memory
        OLLAMA_CONTEXT_LENGTH = ctx;
        OLLAMA_KEEP_ALIVE = "30m";
        OLLAMA_MAX_LOADED_MODELS = "3";
        OLLAMA_NUM_PARALLEL = "1"; # every parallel slot costs another full context of memory
      };
    };

    ##
    ## image generation: sd-server behind llama-swap (unloads when idle). weights download in the
    ## background after a switch; neither boot nor switch waits on it.
    ##

    services.llama-swap = mkIf imagesOn {
      enable = true;
      listenAddress = "0.0.0.0"; # firewall only admits the tailnet
      port = ports.llamaSwap;
      settings = {
        healthCheckTimeout = 600;
        startPort = 10001;
        logLevel = "info";
        models = imageModels;
      };
    };

    systemd.services.llama-swap = mkIf imagesOn {
      environment.MESA_SHADER_CACHE_DIR = "/var/cache/llama-swap/mesa";
      serviceConfig.SupplementaryGroups = ["render" "video"];
    };

    systemd.services.ai-model-fetch = mkIf (imagesOn && imageFiles != []) {
      description = "Download image-generation model weights";
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"];
      after = ["network-online.target"];
      path = [pkgs.curl pkgs.coreutils];
      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        RestartSec = "1min";
        EnvironmentFile = lib.mkIf (cfg.huggingfaceTokenFile != null) cfg.huggingfaceTokenFile;
      };
      script = ''
        failed=0
        auth=()
        if [ -n "''${HF_TOKEN:-}" ]; then auth=(-H "Authorization: Bearer $HF_TOKEN"); fi
        fetch() {
          dest="$1/$(basename "$2")"
          [ -s "$dest" ] && return 0
          mkdir -p "$1"
          echo "fetching $2"
          if curl -fL --retry 5 --retry-delay 10 "''${auth[@]}" -C - -o "$dest.part" "$2"; then
            mv "$dest.part" "$dest"
          else
            failed=1
          fi
        }
        ${lib.concatMapStrings (f: ''
            fetch ${lib.escapeShellArg f.dir} ${lib.escapeShellArg f.url}
          '')
          imageFiles}
        chmod -R a+rX ${modelsDir}
        exit $failed
      '';
    };

    ##
    ## front end
    ##

    services.open-webui = {
      enable = true;
      host = "127.0.0.1";
      port = ports.webui;
      environmentFile = "${secretsDir}/open-webui.env";
      # NB: most of these are "PersistentConfig": read on first start, then the admin panel owns them
      environment =
        {
          SCARF_NO_ANALYTICS = "True";
          DO_NOT_TRACK = "True";
          ANONYMIZED_TELEMETRY = "False";

          WEBUI_URL = "http://${cfg.tailscaleAddress}";
          WEBUI_NAME = "${config.networking.hostName}";

          # chat models come from ollama only
          OLLAMA_BASE_URL = ollamaUrl;
          ENABLE_OPENAI_API = "False";

          # RAG
          RAG_EMBEDDING_ENGINE = "ollama";
          RAG_EMBEDDING_MODEL = cfg.embeddingModel;
          RAG_OLLAMA_BASE_URL = ollamaUrl;

          # web search
          ENABLE_WEB_SEARCH = "True";
          WEB_SEARCH_ENGINE = "searxng";
          SEARXNG_QUERY_URL = "http://127.0.0.1:${toString ports.searx}/search?q=<query>";
          WEB_SEARCH_RESULT_COUNT = "6";
          WEB_SEARCH_CONCURRENT_REQUESTS = "6";
        }
        // lib.optionalAttrs (imagesOn && cfg.images.default != null) {
          ENABLE_IMAGE_GENERATION = "True";
          IMAGE_GENERATION_ENGINE = "openai";
          IMAGES_OPENAI_API_BASE_URL = "http://127.0.0.1:${toString ports.llamaSwap}/v1";
          IMAGES_OPENAI_API_KEY = "sk-local";
          IMAGE_GENERATION_MODEL = cfg.images.default;
          IMAGE_SIZE = cfg.images.size;
          IMAGE_STEPS = toString cfg.images.steps;
        }
        // lib.optionalAttrs cfg.sandbox.enable {
          ENABLE_CODE_EXECUTION = "True";
          CODE_EXECUTION_ENGINE = "jupyter";
          CODE_EXECUTION_JUPYTER_URL = "http://127.0.0.1:${toString ports.jupyter}";
          CODE_EXECUTION_JUPYTER_AUTH = "token";
          CODE_EXECUTION_JUPYTER_TIMEOUT = "300";
          ENABLE_CODE_INTERPRETER = "True";
          CODE_INTERPRETER_ENGINE = "jupyter";
          CODE_INTERPRETER_JUPYTER_URL = "http://127.0.0.1:${toString ports.jupyter}";
          CODE_INTERPRETER_JUPYTER_AUTH = "token";
          CODE_INTERPRETER_JUPYTER_TIMEOUT = "300";
        };
    };

    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;
      virtualHosts =
        {
          ai = {
            default = true;
            listen = [
              {
                addr = "0.0.0.0";
                port = 80;
              }
            ];
            extraConfig = "client_max_body_size 1G;";
            locations."/" = {
              proxyPass = "http://127.0.0.1:${toString ports.webui}";
              proxyWebsockets = true;
              extraConfig = ''
                proxy_buffering off;
                proxy_read_timeout 1h;
                proxy_send_timeout 1h;
              '';
            };
          };
        }
        // lib.optionalAttrs cfg.comfyui.enable {
          comfyui = {
            listen = [
              {
                addr = "0.0.0.0";
                port = ports.comfyui;
              }
            ];
            extraConfig = "client_max_body_size 1G;";
            locations."/" = {
              proxyPass = "http://127.0.0.1:${toString ports.comfyuiLocal}";
              proxyWebsockets = true;
              extraConfig = "proxy_read_timeout 1h;";
            };
          };
        };
    };

    systemd.services.ai-tailscale-serve = mkIf cfg.tailscaleServe {
      description = "Expose open webui over tailscale HTTPS";
      wantedBy = ["multi-user.target"];
      wants = ["tailscaled.service"];
      after = ["tailscaled.service" "open-webui.service"];
      path = [config.services.tailscale.package];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        for _ in $(seq 60); do
          tailscale status >/dev/null 2>&1 && break
          sleep 2
        done
        tailscale serve --bg --https=443 http://127.0.0.1:${toString ports.webui}
      '';
    };

    ##
    ## web search
    ##

    services.searx = {
      enable = true;
      package = pkgs.searxng;
      environmentFile = "${secretsDir}/searx.env";
      settings = {
        general.instance_name = "${config.networking.hostName} search";
        server = {
          bind_address = "0.0.0.0"; # firewall only admits the tailnet
          port = ports.searx;
          secret_key = "$SEARX_SECRET_KEY";
          limiter = false; # open webui hammers it from localhost
          public_instance = false;
          image_proxy = true;
        };
        search = {
          formats = ["html" "json"]; # json is what open webui consumes
          safe_search = 0;
          autocomplete = "duckduckgo";
        };
      };
    };

    ##
    ## sandboxes: everything the models can execute runs in resource-capped containers,
    ## published on loopback only (docker port publishing bypasses the nixos firewall)
    ##

    virtualisation.oci-containers = mkIf (cfg.sandbox.enable || cfg.comfyui.enable) {
      backend = "docker";
      containers =
        lib.optionalAttrs cfg.sandbox.enable {
          open-terminal = {
            image = "ghcr.io/open-webui/open-terminal:latest";
            ports = ["127.0.0.1:${toString ports.terminal}:8000"];
            environmentFiles = ["${secretsDir}/open-terminal.env"];
            volumes = ["ai-open-terminal:/home/user"];
            extraOptions = ["--memory=16g" "--cpus=8" "--pids-limit=4096"];
          };
          jupyter = {
            image = "quay.io/jupyter/scipy-notebook:latest";
            ports = ["127.0.0.1:${toString ports.jupyter}:8888"];
            environmentFiles = ["${secretsDir}/jupyter.env"];
            volumes = ["ai-jupyter:/home/jovyan/work"];
            extraOptions = ["--memory=16g" "--cpus=8" "--pids-limit=4096"];
          };
        }
        // lib.optionalAttrs cfg.comfyui.enable {
          comfyui = {
            image = "docker.io/kyuz0/amd-strix-halo-comfyui:latest";
            ports = ["127.0.0.1:${toString ports.comfyuiLocal}:8188"];
            volumes = [
              "${modelsDir}/comfyui:/opt/ComfyUI/models"
              "ai-comfyui-output:/opt/ComfyUI/output"
              "ai-comfyui-custom-nodes:/opt/ComfyUI/custom_nodes"
            ];
            # the image is built as a toolbox (CMD is bash); these normally come from /etc/profile.d
            environment = {
              TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL = "1";
              TORCH_BLAS_PREFER_HIPBLASLT = "1";
            };
            entrypoint = "/opt/venv/bin/python";
            # kyuz0's flags; --cache-none/--disable-smart-memory hand memory back to the llms between runs
            cmd = [
              "/opt/ComfyUI/main.py"
              "--listen"
              "0.0.0.0"
              "--port"
              "8188"
              "--disable-mmap"
              "--gpu-only"
              "--disable-smart-memory"
              "--cache-none"
              "--bf16-vae"
            ];
            extraOptions = [
              "--device=/dev/kfd"
              "--device=/dev/dri"
              "--security-opt=seccomp=unconfined"
              "--ipc=host"
            ];
          };
        };
    };

    ##
    ## coding sandbox. a full NixOS container: own filesystem (only /nix/store is shared, read-only),
    ## own process tree, memory/cpu caps, and an unprivileged user with no sudo. it shares the host's
    ## network namespace so it can reach ollama on loopback; its sshd is only reachable over the
    ## tailnet. persistent state lives in /var/lib/nixos-containers/coder.
    ##
    ## the user is deliberately NOT uid 1000: the host nix-daemon (whose socket the container uses)
    ## trusts uids by host name, and a trusted nix user is root-equivalent.
    ##

    containers = mkIf cfg.coding.enable {
      coder = {
        autoStart = true;
        privateNetwork = false;
        config = {pkgs, ...}: let
          model = cfg.coding.model;

          # claude code against ollama's anthropic-compatible API. every tier maps to one model so
          # ollama doesn't juggle several. plain `claude` still works with an anthropic account.
          # NB: anthropic doesn't support non-claude backends; this is best effort.
          claudeLocal = pkgs.writeShellScriptBin "claude-local" ''
            m="''${CLAUDE_LOCAL_MODEL:-${model}}"
            unset ANTHROPIC_API_KEY
            export ANTHROPIC_BASE_URL=${ollamaUrl}
            export ANTHROPIC_AUTH_TOKEN=ollama
            export ANTHROPIC_MODEL="$m" ANTHROPIC_DEFAULT_OPUS_MODEL="$m" \
              ANTHROPIC_DEFAULT_SONNET_MODEL="$m" ANTHROPIC_DEFAULT_HAIKU_MODEL="$m" \
              CLAUDE_CODE_SUBAGENT_MODEL="$m"
            # ollama's window is OLLAMA_CONTEXT_LENGTH; compact before it silently truncates
            export CLAUDE_CODE_MAX_CONTEXT_TOKENS=${ctx} CLAUDE_CODE_AUTO_COMPACT_WINDOW=${ctx}
            export CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=1 # third-party backends reject beta fields
            export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
            export API_TIMEOUT_MS=3600000 # loading a big model can take a while
            # the container is the sandbox, so no permission prompts
            exec ${pkgs.claude-code}/bin/claude --dangerously-skip-permissions "$@"
          '';

          # opencode with every model ollama currently has, so whatever you pull in open webui
          # shows up here. pick one with /models, or start with OPENCODE_MODEL=<name> opencode.
          opencodeLocal = pkgs.writeShellScriptBin "opencode" ''
            jq=${pkgs.jq}/bin/jq
            models=$(${pkgs.curl}/bin/curl -sf ${ollamaUrl}/api/tags |
              $jq -c '[.models[].name | {key: ., value: {name: ., limit: {context: ${ctx}, output: 32768}}}] | from_entries') ||
              models='{}'
            m="''${OPENCODE_MODEL:-${model}}"
            case "$m" in *:*) ;; *) m="$m:latest" ;; esac
            OPENCODE_CONFIG_CONTENT=$($jq -nc --argjson models "$models" --arg m "ollama/$m" '{
              "$schema": "https://opencode.ai/config.json",
              model: $m,
              small_model: $m,
              autoupdate: false,
              share: "disabled",
              provider: {ollama: {
                npm: "@ai-sdk/openai-compatible",
                name: "Ollama (${config.networking.hostName})",
                options: {baseURL: "${ollamaUrl}/v1", apiKey: "ollama"},
                models: $models
              }}
            }')
            export OPENCODE_CONFIG_CONTENT
            exec ${pkgs.opencode}/bin/opencode "$@"
          '';

          # your git identity, read from home-manager so it lives in one place
          hostGitUser = config.home-manager.users.synchronous.programs.git.settings.user;
        in {
          system.stateVersion = config.system.stateVersion;
          nixpkgs.config.allowUnfree = true; # claude-code; host nixpkgs.config isn't inherited

          networking.firewall.enable = false; # shared netns: the host firewall applies
          services.openssh = {
            enable = true;
            ports = [cfg.coding.sshPort];
            settings = {
              PasswordAuthentication = false;
              KbdInteractiveAuthentication = false;
              PermitRootLogin = "no";
            };
          };

          users.users.coder = {
            isNormalUser = true;
            uid = 2000;
            shell = pkgs.zsh;
            openssh.authorizedKeys.keys = cfg.coding.authorizedKeys;
          };

          # the host's zsh (home/programs/zsh): same zshrc, p10k prompt and plugins, rebuilt from
          # nixos options since there's no home-manager in here. the agenix'd remote aliases are
          # deliberately left out of the sandbox.
          programs.zsh = {
            enable = true;
            ohMyZsh = {
              enable = true;
              plugins = ["git" "history-substring-search" "colored-man-pages"];
            };
            autosuggestions.enable = true;
            syntaxHighlighting.enable = true;
            interactiveShellInit = lib.mkAfter (builtins.readFile ../home/programs/zsh/zshrc);
            promptInit = ''
              source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
              source ${../home/programs/zsh/p10k}
            '';
          };
          programs.direnv.enable = true;
          # an empty ~/.zshrc keeps zsh's new-user wizard away; everything lives in /etc/zshrc
          systemd.tmpfiles.rules = ["f /home/coder/.zshrc 0644 coder users -"];

          programs.git = {
            enable = true;
            config.user = {inherit (hostGitUser) name email;};
          };

          # builds go through the host daemon as an untrusted user: `nix shell nixpkgs#foo` works
          nix.settings.experimental-features = ["nix-command" "flakes"];

          environment.systemPackages = with pkgs; [
            claude-code
            claudeLocal
            opencodeLocal
            codex # `codex --oss -m <ollama model>`
            aider-chat
            ollama # `ollama list` etc. against the host's server
            gh
            nodejs
            python3
            uv
            gcc
            gnumake
            pkg-config
            ripgrep
            fd
            jq
            curl
            wget
            tmux
            neovim
            htop
            tree
            file
            unzip
            # things the zshrc aliases / keybinds expect
            eza
            btop
            fzf
            nnn
            yazi
          ];

          environment.variables = {
            # claude code: the nix store is read-only, and no phoning home
            DISABLE_AUTOUPDATER = "1";
            DISABLE_TELEMETRY = "1";
            DISABLE_ERROR_REPORTING = "1";
            CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY = "1";

            OLLAMA_HOST = ollamaUrl;
            OLLAMA_API_BASE = ollamaUrl; # aider (litellm)
            AIDER_MODEL = "ollama_chat/${model}";
            AIDER_ANALYTICS_DISABLE = "true";
            AIDER_CHECK_UPDATE = "false";
          };
        };
      };
    };

    systemd.services."container@coder" = mkIf cfg.coding.enable {
      serviceConfig = {
        MemoryMax = cfg.coding.memoryMax;
        CPUQuota = "1200%"; # 12 of 32 threads
        TasksMax = 8192;
      };
    };

    systemd.tmpfiles.rules =
      ["d ${modelsDir} 0755 root root -"]
      # the comfyui bind mount hides the image's model tree, so recreate the usual layout
      ++ lib.optionals cfg.comfyui.enable (map (d: "d ${modelsDir}/comfyui/${d} 0755 root root -") [
        "checkpoints"
        "clip_vision"
        "diffusion_models"
        "loras"
        "text_encoders"
        "unet"
        "upscale_models"
        "vae"
      ]);

    ##
    ## secrets, generated once and kept across rebuilds
    ##

    systemd.services.ai-secrets = {
      description = "Generate local secrets for the AI stack";
      wantedBy = ["multi-user.target"];
      before = secretConsumers;
      requiredBy = secretConsumers;
      path = [pkgs.openssl pkgs.coreutils];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        UMask = "0077";
      };
      script = ''
        set -eu
        dir=${secretsDir}
        mkdir -p "$dir"
        chmod 700 "$dir"
        key() {
          [ -s "$dir/$1.key" ] || openssl rand -hex 32 > "$dir/$1.key"
          cat "$dir/$1.key"
        }
        webui=$(key webui)
        searx=$(key searx)
        jupyter=$(key jupyter)
        terminal=$(key terminal)
        terminals='${terminalConnections}'
        terminals=''${terminals//@TERMINAL_KEY@/$terminal}

        # read by systemd (quoted values allowed)
        cat > "$dir/open-webui.env" <<EOF
        WEBUI_SECRET_KEY=$webui
        CODE_EXECUTION_JUPYTER_AUTH_TOKEN=$jupyter
        CODE_INTERPRETER_JUPYTER_AUTH_TOKEN=$jupyter
        ${lib.optionalString cfg.sandbox.enable "TERMINAL_SERVER_CONNECTIONS='$terminals'"}
        EOF
        printf 'SEARX_SECRET_KEY=%s\n' "$searx" > "$dir/searx.env"
        # read by docker --env-file (no quoting)
        printf 'JUPYTER_TOKEN=%s\n' "$jupyter" > "$dir/jupyter.env"
        printf 'OPEN_TERMINAL_API_KEY=%s\n' "$terminal" > "$dir/open-terminal.env"
      '';
    };

    networking.firewall.interfaces.${cfg.interface}.allowedTCPPorts =
      [80 ports.ollama ports.searx]
      ++ lib.optional imagesOn ports.llamaSwap
      ++ lib.optional cfg.comfyui.enable ports.comfyui
      ++ lib.optional cfg.coding.enable cfg.coding.sshPort;
  };
}
