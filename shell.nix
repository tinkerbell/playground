let _pkgs = import <nixpkgs> { };
in
{ pkgs ?
  import
    (_pkgs.fetchFromGitHub {
      owner = "NixOS";
      repo = "nixpkgs";
      #branch@date: master@2021-03-18
      rev = "800a3dd90970a277e3f6853633bd7faf04d6691e";
      sha256 = "07gzvf3m3vh9kkig2x9iybv8yr04kvmrx665z0fb0n5h55ha4v8y";
    }) { }
}:

with pkgs;

mkShell {
  buildInputs = [ go nodePackages.prettier shellcheck shfmt terraform gpgme packer vagrant ];
}
