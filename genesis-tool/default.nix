with import <nixpkgs> {};

let
  ghc = haskellPackages.ghcWithPackages (ps: [ ps.aeson ps.base58-bytestring ps.base16-bytestring ]);
in runCommand "convert" { buildInputs = [ ghc ]; } ''
  mkdir -p $out/bin
  ghc ${./convert.hs} -o $out/bin/convert
''
