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
      };
      secretsDir = "/home/synchronous/.agenix/agenix";
      secretsMountPoint = "/home/synchronous/.agenix/agenix.d";
      identityPaths = ["/home/synchronous/.ssh/id_ed25519"];
    };
  };
}
