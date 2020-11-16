let _pkgs = import <nixpkgs> { };
in
{ pkgs ?
  import
    (_pkgs.fetchFromGitHub {
      owner = "NixOS";
      repo = "nixpkgs";
      #branch@date: nixpkgs-unstable@2020-11-04
      rev = "dfea4e4951a3cee4d1807d8d4590189cf16f366b";
      sha256 = "02j7f5l2p08144b2fb7pg6sbni5km5y72k3nk3i7irddx8j2s04i";
    }) { }
}:

with pkgs;

mkShell {
  buildInputs = [ go nodePackages.prettier shellcheck shfmt terraform gpgme ];
}
