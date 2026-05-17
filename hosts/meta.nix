{
  config,
  pkgs,
  lib,
  ...
}: {
  options = {
    res = lib.mkOption {
      type = lib.types.str;
      default = "1920x1080";
      description = "screen resolution";
    };

    driver-main = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "primary driver machine (full desktop)";
    };

    driver-secondary = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "secondary driver machine (lighter desktop)";
    };

    server-master = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "k3s control-plane node";
    };

    server-worker = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "k3s worker node";
    };

    secrets.eval = lib.mkOption {
      type = lib.types.attrs;
      default = {
        ips = import ../secrets/eval/ips.nix;
      };
    };
  };

  config = {
    age = {
      secrets = {
        zsh_remote = {
          file = ../secrets/zsh_remote.age;
          owner = "synchronous";
          mode = "0400";
        };
        tailscale-rq = {
          file = ../secrets/tailscale-rq.age;
          owner = "synchronous";
          mode = "0400";
        };
        ssh-pub = {
          file = ../secrets/ssh-pub.age;
          owner = "synchronous";
          mode = "0400";
        };
        kube = {
          file = ../secrets/kube.age;
          owner = "synchronous";
          mode = "0400";
        };
        ip-master-k3s = {
          file = ../secrets/ip-master-k3s.age;
          owner = "synchronous";
          mode = "0400";
        };
        ip-cmu = {
          file = ../secrets/ip-cmu.age;
          owner = "synchronous";
          mode = "0400";
        };
        git-crypt = {
          file = ../secrets/git-crypt.age;
          owner = "synchronous";
          mode = "0400";
        };
      };
      secretsDir = "/home/synchronous/.agenix/agenix";
      secretsMountPoint = "/home/synchronous/.agenix/agenix.d";
      identityPaths = ["/home/synchronous/.ssh/id_ed25519"];
    };
  };
}
