{ sourcePaths ? import ./nix/sources.nix
, system ? builtins.currentSystem
, crossSystem ? null
, config ? {}
}@args: with import ./nix args; {

  shell = let
    genesisFile = iohkNix.cardanoLib.environments.${globals.environmentName}.genesisFile or "please/set/globals.environmentName";

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
    create-shelley-genesis-and-keys =
      let nbCoreNodes = builtins.length globals.topology.coreNodes;
          maxSupply = 10000000000 * nbCoreNodes;
      in writeShellScriptBin "create-shelley-genesis-and-keys" ''
        set -euxo pipefail

        cd ${toString ./keys}
        cardano-cli shelley genesis create-genesis --genesis-dir . --supply ${toString maxSupply} --genesis-delegates ${toString nbCoreNodes}
        mkdir -p node-keys
        cd node-keys
        for i in {1..${toString nbCoreNodes}}; do
          cardano-cli shelley node key-gen-VRF --verification-key-file node-vrf$i.vkey --signing-key-file node-vrf$i.skey
          cardano-cli shelley node key-gen-KES --verification-key-file node-kes$i.vkey --signing-key-file node-kes$i.skey --kes-duration 30
          cardano-cli shelley node issue-op-cert --hot-kes-verification-key-file node-kes$i.vkey --cold-signing-key-file ../delegate-keys/delegate$i.skey --operational-certificate-issue-counter ../delegate-keys/delegate-opcert$i.counter --kes-period 0 --out-file delegate$i.opcert
        done
     '';
  in  mkShell {
    buildInputs = [ niv nixops nix cardano-cli telnet dnsutils mkDevGenesis nix-diff migrate-keys create-shelley-genesis-and-keys ] ++
                  (with cardano-sl-pkgs.nix-tools.exes; [ cardano-sl-auxx cardano-sl-tools ]);
    NIX_PATH = "nixpkgs=${path}";
    NIXOPS_DEPLOYMENT = "${globals.deploymentName}";
    passthru = {
      gen-graylog-creds = iohk-ops-lib.scripts.gen-graylog-creds { staticPath = ./static; };
    };
  };
}
