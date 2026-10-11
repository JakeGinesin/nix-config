{
  config,
  pkgs,
  ...
}: {
  services.ssh-agent.enable = true;
  programs.git = {
    enable = true;
    package = pkgs.gitFull;

    userName = "JakeGinesin";
    userEmail = "jakeginesin@gmail.com";

    # extraConfig = {
    # commit.gpgsign = true;
    # gpg.format = "ssh";
    # gpg.ssh.allowedSignersFile = "/home/synchronous/.ssh/allowed_signers";
    # user.signingkey = "/home/synchronous/.ssh/github_synchronous_signing.pub";
    # rebase.updateRefs = true;
    # };
  };
}
