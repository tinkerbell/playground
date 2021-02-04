let _pkgs = import <nixpkgs> { };
in
{ pkgs ?
  import
    (_pkgs.fetchFromGitHub {
      owner = "NixOS";
      repo = "nixpkgs";
      #branch@date: nixpkgs-unstable@2020-11-19
      rev = "4f3475b113c93d204992838aecafa89b1b3ccfde";
      sha256 = "158iik656ds6i6pc672w54cnph4d44d0a218dkq6npzrbhd3vvbg";
    }) { }
}:

with pkgs;

mkShell {
  buildInputs = [ go nodePackages.prettier shellcheck shfmt terraform gpgme packer vagrant ];
}
