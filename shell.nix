let _pkgs = import <nixpkgs> { };
in { pkgs ? import (_pkgs.fetchFromGitHub {
  owner = "NixOS";
  repo = "nixpkgs";
  #branch@date: master@2022-06-02
  rev = "17e891b141ca8e599ebf6443d0870a67dd98f94f";
  sha256 = "0qiyl04s4q0b3dhvyryz10hfdqhb2c7hk2lqn5llsb8lxsqj07l9";
}) { } }:

with pkgs;

mkShell {
  buildInputs = [
    docker-compose
    go
    nodePackages.prettier
    jq
    shellcheck
    shfmt
    terraform_0_14
    gpgme
    packer
    rufo
    vagrant
  ];
}
