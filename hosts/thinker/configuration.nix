{
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../../system/system.nix
    ../meta.nix
    ../../extras/ssh.nix
    ../../extras/ai.nix
  ];

  config = {
    networking.hostName = "thinker"; # Define your hostname.
    res = "1920x1080";

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "backup";
      users.synchronous.imports = [../../home/home.nix];
    };

    # Bootloader.
    # boot.loader.grub.enable = true;
    # boot.loader.grub.device = "/dev/nvme0n1";
    # boot.loader.grub.useOSProber = true;
    # services.logind.lidSwitchExternalPower = "ignore";

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    boot.loader.grub.enable = false;
    boot.kernelModules = ["mt7921e"];

    ##
    ## local AI server (../../extras/ai.nix)
    ## framework desktop: ryzen ai max+ 395 (strix halo, radeon 8060s = gfx1151), 128GB unified memory
    ##
    ## BIOS: set the iGPU's dedicated VRAM / UMA frame buffer to the minimum (512MB). the GPU then
    ## takes memory dynamically through GTT, capped by ttm.pages_limit below.
    ## check after boot: `cat /sys/module/ttm/parameters/pages_limit`, `amdgpu_top`, `vulkaninfo --summary`
    ##

    boot.kernelParams = [
      # let the iGPU map up to 120GiB (counted in 4KiB pages); ~8GiB stays with the host
      "ttm.pages_limit=31457280"
      # ~5-15% faster prompt processing / memory bandwidth on strix halo; costs DMA isolation and the NPU
      "amd_iommu=off"
    ];

    assertions = [
      {
        assertion = lib.versionAtLeast config.boot.kernelPackages.kernel.version "6.18.4";
        message = "thinker (strix halo) needs linux >= 6.18.4 for working amdgpu KFD/ROCm";
      }
    ];

    ai = {
      enable = true;
      tailscaleAddress = "100.74.123.109";

      # served by llama-swap (llama.cpp, vulkan); weights download on first use into
      # /var/cache/llama-swap/huggingface/hub. one llm is resident at a time; idle ones unload.
      llm.default = "gpt-oss-120b";
      llm.models = {
        # fast generalist, ~50 tok/s. reasoning effort is a per-chat/model param in open webui
        "gpt-oss-120b" = {
          hf = "ggml-org/gpt-oss-120b-GGUF:MXFP4"; # 63GB
          args = ["--temp" "1.0" "--top-p" "1.0" "--top-k" "0"];
        };
        "gpt-oss-20b" = {
          hf = "ggml-org/gpt-oss-20b-GGUF:MXFP4"; # 12GB
          args = ["--temp" "1.0" "--top-p" "1.0" "--top-k" "0"];
        };
        # the strongest thing that fits: 125B MoE, 6B active, ~20 tok/s
        "qwen3.8-flash-next" = {
          hf = "unsloth/Qwen3.8-Flash-Next-GGUF:UD-Q3_K_XL"; # 90GB
          ctx = 65536;
        };
        "qwen3.5-122b-a10b" = {
          hf = "unsloth/Qwen3.5-122B-A10B-GGUF:UD-Q4_K_XL"; # 77GB
          ctx = 131072;
        };
        # agentic coding, 80B MoE, 3B active
        "qwen3-coder-next" = {
          hf = "unsloth/Qwen3-Coder-Next-GGUF:UD-Q4_K_XL"; # 50GB
          ctx = 131072;
        };
        # small, quick, and multimodal (accepts images)
        "qwen3.6-35b-a3b" = {
          hf = "unsloth/Qwen3.6-35B-A3B-GGUF:UD-Q4_K_XL"; # 22GB
          ctx = 131072;
        };
      };

      # stable-diffusion.cpp behind llama-swap, wired into open webui's image button
      images.default = "z-image-turbo";
      images.models."z-image-turbo" = {
        files = {
          diffusion-model = "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/diffusion_models/z_image_turbo_bf16.safetensors";
          vae = "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/vae/ae.safetensors";
          llm = "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/text_encoders/qwen_3_4b.safetensors";
        };
        # request defaults; open webui only sends prompt + size. seed -1 = random per image
        args = ["--cfg-scale" "1.0" "--steps" "8" "--diffusion-fa" "--seed" "-1" "-W" "1024" "-H" "1024"];
      };

      # more models: any GGUF repo on hugging face works as `hf = "user/repo:quant"`; local files
      # (fine-tunes, conversions) go in /var/lib/ai-models/gguf and use `file = "/var/lib/ai-models/gguf/x.gguf"`.
      # for gated repos: huggingfaceTokenFile = <agenix secret containing HF_TOKEN=...>;
      # ad hoc, without rebuilding: open webui -> admin -> models -> pull `hf.co/user/repo:quant` (via ollama)

      # sandboxed coding agents: `ssh -p 2222 coder@100.74.123.109`, then
      #   claude                                    claude code on your anthropic account
      #   claude-local                              claude code on the local model below (unsupported by anthropic, best effort)
      #   opencode                                  preconfigured with every llama-swap model
      #   aider / codex --oss                       llama-swap / ollama
      # no sudo inside; `nix shell nixpkgs#foo` for tools. `claude --dangerously-skip-permissions` is fair game in there.
      coding = {
        enable = true;
        model = "qwen3-coder-next";
      };

      # node-based image/video workflows (kyuz0's ROCm container, ~20GB image). put weights in
      # /var/lib/ai-models/comfyui/<kind>/; UI at http://100.74.123.109:8188
      comfyui.enable = false;

      # https://thinker.<tailnet>.ts.net (needed for voice input); enable HTTPS in the tailnet admin first
      tailscaleServe = false;
    };
  };
}
