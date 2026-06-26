# so yeah you gotta run `agenix -e secret.age` to actually edit a secret
let
  key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEw4Uqg9UBakoOpS4nVGE3ePKHnst0+02lFN04n2IyKb ginesin.j@northeastern.edu";
  host = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJXmQu68MmXb/NDWIprtw2jBxbULz8Rc+rttOqfKR3Fk jakeginesin@gmail.com";
in {
  "git-crypt.age".publicKeys = [key];
  "zsh_remote.age".publicKeys = [key];
  "tailscale-rq.age".publicKeys = [key];
  "ssh-pub.age".publicKeys = [key];
  "kube.age".publicKeys = [key];
  "ip-master-k3s.age".publicKeys = [key];
  "ip-cmu.age".publicKeys = [key];
  "restic-password.age".publicKeys = [host];
}
