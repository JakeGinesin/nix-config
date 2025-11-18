# so yeah you gotta run `agenix -e secret.age` to actually edit a secret
let
  key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEw4Uqg9UBakoOpS4nVGE3ePKHnst0+02lFN04n2IyKb ginesin.j@northeastern.edu";
in {
  "zsh_remote.age".publicKeys = [key];
  "tailscale-rq.age".publicKeys = [key];
  "ssh-pub.age".publicKeys = [key];
  "kube.age".publicKeys = [key];
  "ip-master-k3s.age".publicKeys = [key];
  "ip-cmu.age".publicKeys = [key];
}
