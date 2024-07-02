{...}: {
  # OpenSSH Version 9.8p1 fixes CVE-2024-6387
  programs.ssh.package = (
    builtins.getFlake "github:nixos/nixpkgs/b9014df496d5b68bf7c0145d0e9b0f529ce4f2a8"
  ).legacyPackages.x86_64-linux.openssh;
}
