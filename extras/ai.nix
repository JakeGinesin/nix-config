# local AI server: llama-swap (llama.cpp + stable-diffusion.cpp on Vulkan), Ollama,
# Open WebUI, SearXNG web search, and sandboxed code/terminal execution (docker).
#
# everything that listens beyond loopback is only opened on the tailscale interface.
#
#   http://<tailscaleAddress>/        open webui (first account created becomes admin)
#   http://<tailscaleAddress>:9292    llama-swap: OpenAI-compatible API + /ui (logs, loaded models)
#   http://<tailscaleAddress>:11434   ollama API
#   http://<tailscaleAddress>:8890    searxng
#   http://<tailscaleAddress>:8188    comfyui (if enabled)
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
  modelsDir = "/var/lib/ai-models"; # sd.cpp / comfyui weights (llama.cpp -hf downloads live in llama-swap's state dir)

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

  # vulkan (RADV) is the most stable and usually the fastest backend on gfx1151
  llamaCpp = pkgs.llama-cpp-vulkan;
  sdCpp = pkgs.stable-diffusion-cpp-vulkan; # ships sd-server (its meta.mainProgram is stale)

  # llama-swap substitutes ${PORT} itself, so it is kept literal here
  llmCmd = m:
    "${llamaCpp}/bin/llama-server --host 127.0.0.1 --port \${PORT} "
    + lib.escapeShellArgs ((
        if m.hf != null
        then ["-hf" m.hf]
        else ["--model" m.file]
      )
      ++ [
        "--ctx-size"
        (toString m.ctx)
        "--n-gpu-layers"
        "999"
        "--flash-attn"
        "on"
        "--load-mode" # read weights into memory instead of mmap; mmap is far slower on strix halo
        "none"
        "--jinja"
        "--parallel"
        "1"
      ]
      ++ m.args);

  imageCmd = id: m:
    "${sdCpp}/bin/sd-server --listen-ip 127.0.0.1 --listen-port \${PORT} "
    + lib.escapeShellArgs (
      lib.concatLists (lib.mapAttrsToList (flag: url: ["--${flag}" "${modelsDir}/${id}/${baseNameOf url}"]) m.files)
      ++ m.args
    );

  llmModels =
    lib.mapAttrs (_: m: {
      inherit (m) name ttl;
      cmd = llmCmd m;
    })
    cfg.llm.models;

  imageModels = lib.optionalAttrs cfg.images.enable (lib.mapAttrs (id: m: {
      inherit (m) name ttl;
      cmd = imageCmd id m;
      checkEndpoint = "/v1/models";
    })
    cfg.images.models);

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

  llmModule = types.submodule ({name, ...}: {
    options = {
      hf = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "unsloth/Qwen3.6-35B-A3B-GGUF:UD-Q4_K_XL";
        description = ''
          any Hugging Face GGUF repo, as repo[:quant] for `llama-server -hf`. downloaded on first
          use; split files and the vision projector (mmproj) are fetched automatically.
        '';
      };
      file = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "/var/lib/ai-models/gguf/my-finetune-Q8_0.gguf";
        description = "a local GGUF instead of `hf` (first shard for split models)";
      };
      name = mkOption {
        type = types.str;
        default = name;
        description = "display name in llama-swap / open webui";
      };
      ctx = mkOption {
        type = types.int;
        default = 0;
        description = "context size; 0 = the model's trained maximum";
      };
      ttl = mkOption {
        type = types.int;
        default = 1800;
        description = "seconds of inactivity before llama-swap unloads the model";
      };
      args = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "extra llama-server arguments (sampling defaults etc.)";
      };
    };
  });

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
      description = ''
        file containing `HF_TOKEN=hf_...`, for gated/private Hugging Face repos (llama.cpp -hf
        downloads and the image-weight fetcher). public repos need nothing.
      '';
    };

    llm = {
      models = mkOption {
        type = types.attrsOf llmModule;
        default = {};
        description = "llama.cpp models served by llama-swap (the id is the OpenAI model name)";
      };
      default = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "default model id in open webui";
      };
    };

    ollama.models = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "ollama models pulled at boot";
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
        pointed at the local models, reachable with `ssh -p <sshPort> coder@<tailscaleAddress>`
      '';
      model = mkOption {
        type = types.nullOr types.str;
        default = cfg.llm.default;
        defaultText = lib.literalExpression "config.ai.llm.default";
        description = "llama-swap model the agents use by default";
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
    assertions =
      lib.mapAttrsToList (id: m: {
        assertion = (m.hf == null) != (m.file == null);
        message = "ai.llm.models.${id}: set exactly one of `hf` or `file`";
      })
      cfg.llm.models
      ++ [
        {
          assertion = cfg.coding.enable -> cfg.coding.model != null;
          message = "ai.coding.model (or ai.llm.default) must be set";
        }
      ];

    hardware.graphics.enable = true;

    environment.systemPackages = [
      llamaCpp # llama-bench, llama-cli, ...
      sdCpp
      pkgs.amdgpu_top
      pkgs.nvtopPackages.amd
      pkgs.vulkan-tools
      pkgs.python3Packages.huggingface-hub # `hf download ...`
    ];

    ##
    ## inference
    ##

    services.llama-swap = {
      enable = true;
      listenAddress = "0.0.0.0"; # firewall only admits the tailnet
      port = ports.llamaSwap;
      settings = {
        # first use of a model downloads it, which can take a long time
        healthCheckTimeout = 3600;
        startPort = 10001;
        logLevel = "info";
        models = llmModels // imageModels;
        # one llm and one image model may be resident at the same time
        groups =
          {
            llm = {
              swap = true;
              exclusive = false;
              members = lib.attrNames llmModels;
            };
          }
          // lib.optionalAttrs (imageModels != {}) {
            image = {
              swap = true;
              exclusive = false;
              members = lib.attrNames imageModels;
            };
          };
      };
    };

    systemd.services.llama-swap = {
      wants = ["network-online.target"];
      after = ["network-online.target"];
      # the module already points LLAMA_CACHE (-hf downloads) at /var/cache/llama-swap/huggingface/hub
      environment.MESA_SHADER_CACHE_DIR = "/var/cache/llama-swap/mesa";
      serviceConfig = {
        SupplementaryGroups = ["render" "video"];
        EnvironmentFile = lib.mkIf (cfg.huggingfaceTokenFile != null) cfg.huggingfaceTokenFile;
      };
    };

    services.ollama = {
      enable = true;
      package = pkgs.ollama-vulkan;
      host = "0.0.0.0";
      port = ports.ollama;
      loadModels = lib.unique ([cfg.embeddingModel] ++ cfg.ollama.models);
      environmentVariables = {
        OLLAMA_VULKAN = "1";
        OLLAMA_FLASH_ATTENTION = "1";
        OLLAMA_KV_CACHE_TYPE = "q8_0";
        OLLAMA_CONTEXT_LENGTH = "32768";
        OLLAMA_KEEP_ALIVE = "30m";
        OLLAMA_MAX_LOADED_MODELS = "2";
        OLLAMA_NUM_PARALLEL = "1";
      };
    };

    # weights for sd-server; runs in the background so neither boot nor switch waits on it
    systemd.services.ai-model-fetch = mkIf (cfg.images.enable && imageFiles != []) {
      description = "Download image-generation model weights";
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"];
      after = ["network-online.target"];
      path = [pkgs.curl pkgs.coreutils];
      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        RestartSec = "5min";
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

          # backends
          OLLAMA_BASE_URL = "http://127.0.0.1:${toString ports.ollama}";
          OPENAI_API_BASE_URLS = "http://127.0.0.1:${toString ports.llamaSwap}/v1";
          OPENAI_API_KEYS = "sk-local";

          # RAG
          RAG_EMBEDDING_ENGINE = "ollama";
          RAG_EMBEDDING_MODEL = cfg.embeddingModel;
          RAG_OLLAMA_BASE_URL = "http://127.0.0.1:${toString ports.ollama}";

          # web search
          ENABLE_WEB_SEARCH = "True";
          WEB_SEARCH_ENGINE = "searxng";
          SEARXNG_QUERY_URL = "http://127.0.0.1:${toString ports.searx}/search?q=<query>";
          WEB_SEARCH_RESULT_COUNT = "6";
          WEB_SEARCH_CONCURRENT_REQUESTS = "6";
        }
        // lib.optionalAttrs (cfg.llm.default != null) {
          DEFAULT_MODELS = cfg.llm.default;
        }
        // lib.optionalAttrs (cfg.images.enable && cfg.images.default != null) {
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
    ## network namespace so it can reach the local model endpoints on loopback; its sshd is only
    ## reachable over the tailnet. persistent state lives in /var/lib/nixos-containers/coder.
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
          llamaSwapUrl = "http://127.0.0.1:${toString ports.llamaSwap}";

          # claude code against the local models (anthropic /v1/messages via llama-swap -> llama-server).
          # every tier maps to one model so llama-swap never swaps mid-session. plain `claude` still
          # works with an anthropic account. NB: anthropic doesn't support non-claude backends.
          claudeLocal = pkgs.writeShellScriptBin "claude-local" ''
            m="''${CLAUDE_LOCAL_MODEL:-${model}}"
            unset ANTHROPIC_API_KEY
            export ANTHROPIC_BASE_URL=${llamaSwapUrl}
            export ANTHROPIC_AUTH_TOKEN=sk-local
            export ANTHROPIC_MODEL="$m" ANTHROPIC_DEFAULT_OPUS_MODEL="$m" \
              ANTHROPIC_DEFAULT_SONNET_MODEL="$m" ANTHROPIC_DEFAULT_HAIKU_MODEL="$m" \
              CLAUDE_CODE_SUBAGENT_MODEL="$m"
            export CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=1 # llama-server rejects beta fields
            export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
            export API_TIMEOUT_MS=3600000 # model loads / downloads can be slow
            exec ${pkgs.claude-code}/bin/claude "$@"
          '';

          opencodeConfig = {
            "$schema" = "https://opencode.ai/config.json";
            model = "thinker/${model}";
            small_model = "thinker/${model}"; # same model: no swapping
            autoupdate = false;
            share = "disabled";
            provider.thinker = {
              npm = "@ai-sdk/openai-compatible";
              name = "${config.networking.hostName} (llama-swap)";
              options = {
                baseURL = "${llamaSwapUrl}/v1";
                apiKey = "sk-local";
              };
              models =
                lib.mapAttrs (_: m: {
                  inherit (m) name;
                  limit = {
                    context =
                      if m.ctx > 0
                      then m.ctx
                      else 131072;
                    output = 32768;
                  };
                })
                cfg.llm.models;
            };
          };
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
            openssh.authorizedKeys.keys = cfg.coding.authorizedKeys;
          };

          # builds go through the host daemon as an untrusted user: `nix shell nixpkgs#foo` works
          nix.settings.experimental-features = ["nix-command" "flakes"];
          programs.git.enable = true;

          environment.systemPackages = with pkgs; [
            claude-code
            claudeLocal
            opencode
            codex # `codex --oss -m gpt-oss:20b` runs against ollama
            aider-chat
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
          ];

          environment.etc."opencode/opencode.json".text = builtins.toJSON opencodeConfig;

          environment.variables = {
            # claude code: the nix store is read-only, and no phoning home
            DISABLE_AUTOUPDATER = "1";
            DISABLE_TELEMETRY = "1";
            DISABLE_ERROR_REPORTING = "1";
            CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY = "1";

            OPENCODE_CONFIG = "/etc/opencode/opencode.json";

            AIDER_OPENAI_API_BASE = "${llamaSwapUrl}/v1";
            AIDER_OPENAI_API_KEY = "sk-local";
            AIDER_MODEL = "openai/${model}";
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
      [
        "d ${modelsDir} 0755 root root -"
        # drop-in spot for local GGUFs (`ai.llm.models.<id>.file`), e.g. `hf download <repo> --include '*Q8_0*' --local-dir ...`
        "d ${modelsDir}/gguf 0775 root wheel -"
      ]
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
      [80 ports.llamaSwap ports.ollama ports.searx]
      ++ lib.optional cfg.comfyui.enable ports.comfyui
      ++ lib.optional cfg.coding.enable cfg.coding.sshPort;
  };
}
