{
  config,
  pkgs,
  ...
}: {
  services.openssh.enable = true;

  # Disable password login for security
  services.openssh.settings.PasswordAuthentication = false;
  services.openssh.settings.PermitRootLogin = "no";

  # Add your authorized key for a specific user
  programs.zsh.enable = true;
  users.users.synchronous = {
    isNormalUser = true;
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEw4Uqg9UBakoOpS4nVGE3ePKHnst0+02lFN04n2IyKb ginesin.j@northeastern.edu"
    ];
  };
}
