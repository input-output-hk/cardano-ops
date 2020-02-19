{ sourcePaths ? import ./nix/sources.nix
, system ? builtins.currentSystem
, crossSystem ? null
, config ? {}
}@args: with import ./nix args; {

  shell = let
    cardanoSL = import sourcePaths.cardano-sl {};
    genesisFile = (import sourcePaths.iohk-nix {}).cardanoLib.environments.${globals.environmentName}.genesisFile or "please/set/globals.environmentName";


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
    migrate-keys = writeShellScriptBin "migrate-keys" ''
        i=0
        for k in keys/*.sk; do
          ((i++))
          signing_key=keys/delegate-keys.00$i.key
          echo "migrating $k to $signing_key"
          cardano-cli migrate-delegate-key-from --byron-legacy --from $k --real-pbft --to $signing_key
          pk=$(cardano-cli signing-key-public --real-pbft --secret $signing_key | fgrep 'public key (base64):' | cut -d: -f2 | xargs echo -n)
          delegate_cert=keys/delegation-cert.00$i.json
          echo "generating delegation certificate for $pk in $delegate_cert"
          ${jq}/bin/jq ".heavyDelegation | .[] | select(.delegatePk == \"$pk\")" < ${genesisFile} > $delegate_cert
        done
     '';
  in  mkShell {
    buildInputs = [ niv nixops nix cardano-cli telnet dnsutils mkDevGenesis nix-diff migrate-keys ] ++
                  (with cardanoSL.nix-tools.exes; [ cardano-sl-auxx cardano-sl-tools ]);
    NIX_PATH = "nixpkgs=${path}";
    NIXOPS_DEPLOYMENT = "${globals.deploymentName}";
    passthru = {
      gen-graylog-creds = iohk-ops-lib.scripts.gen-graylog-creds { staticPath = ./static; };
    };
  };
}
