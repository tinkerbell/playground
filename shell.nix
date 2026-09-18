# Pinned via builtins.fetchTarball so no <nixpkgs> channel/NIX_PATH entry is required.
{ pkgs ? import (builtins.fetchTarball {
  #branch@date: master@2022-06-02
  url =
    "https://github.com/NixOS/nixpkgs/archive/17e891b141ca8e599ebf6443d0870a67dd98f94f.tar.gz";
  sha256 = "0qiyl04s4q0b3dhvyryz10hfdqhb2c7hk2lqn5llsb8lxsqj07l9";
}) { } }:

with pkgs;

mkShell {
  buildInputs = [
    nodePackages.prettier
    jq
    shellcheck
    shfmt
    rufo
  ];
}
