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

      # chat models live in ollama and are managed from open webui:
      #   admin panel -> settings -> models -> "pull a model": an ollama.com name
      #   (gpt-oss:120b, gpt-oss:20b, qwen3-coder-next, ...) or any GGUF on hugging face as
      #   hf.co/<user>/<repo>:<quant>. progress shows there; delete from the same page.
      # ollama loads models on demand and unloads idle ones. the RAG embedding model and the
      # coding model below are pulled automatically.

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

      # sandboxed coding agents: `ssh -p 2222 coder@100.74.123.109`, then
      #   opencode       every model ollama has (pull more in open webui); /models to switch
      #   claude-local   claude code on `model` below (or CLAUDE_LOCAL_MODEL=...), no permission prompts
      #                  (unsupported by anthropic, best effort)
      #   claude         claude code on your anthropic account
      #   aider / codex --oss -m <model>
      # no sudo inside; `nix shell nixpkgs#foo` for tools.
      coding = {
        enable = true;
        model = "qwen3-coder-next"; # ollama.com/library/qwen3-coder-next: 80B MoE, 3B active, 52GB
      };

      # node-based image/video workflows (kyuz0's ROCm container, ~20GB image). put weights in
      # /var/lib/ai-models/comfyui/<kind>/; UI at http://100.74.123.109:8188
      comfyui.enable = false;

      # https://thinker.<tailnet>.ts.net (needed for voice input); enable HTTPS in the tailnet admin first
      tailscaleServe = false;
    };
  };
}
