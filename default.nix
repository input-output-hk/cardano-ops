{ sourcePaths ? import ./nix/sources.nix
, system ? builtins.currentSystem
, crossSystem ? null
, config ? {}
}@args: with import ./nix args; {

  shell = let
    cardanoSL = import sourcePaths.cardano-sl {};
    mkDevGenesis = writeShellScriptBin "make-dev-genesis" (builtins.replaceStrings
      [ "\${RUNNER}"
        "SCRIPTDIR=$(dirname $0)"
        "TARGETDIR=\"\${CONFIGDIR}/\${GENHASH:0:5}"
        "--n-delegate-addresses         \${n_delegates}"
      ]
      [ ""
        "SCRIPTDIR=${sourcePaths.cardano-node}/scripts"
        ("TARGETDIR=\"" + toString ./keys)
        ""
      ]
     (builtins.readFile (sourcePaths.cardano-node + "/scripts/genesis.sh")));
  in  mkShell {
    buildInputs = [ niv nixops nix cardano-cli telnet dnsutils mkDevGenesis nix-diff ] ++
                  (with cardanoSL.nix-tools.exes; [ cardano-sl-auxx cardano-sl-tools ]);
    NIX_PATH = "nixpkgs=${path}";
    NIXOPS_DEPLOYMENT = "${globals.deploymentName}";
    passthru = {
      gen-graylog-creds = iohk-ops-lib.scripts.gen-graylog-creds { staticPath = ./static; };
    };
  };
}
