{ config ? {}
, pkgs ? import ./nix {
    inherit config;
  }
}:
with pkgs;
let
  nivOverrides = writeShellScriptBin "niv-overrides" ''
    niv --sources-file ${toString globals.sourcesJsonOverride} $@
  '';
  genesisFile = globals.environmentConfig.genesisFile or "please set globals.environmentName or globals.environmentConfig.genesisFile";

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
        maxSupply = 20000000000000000 * nbCoreNodes;
    in writeShellScriptBin "create-shelley-genesis-and-keys" ''
      set -euxo pipefail

      cd ${toString ./keys}
      if [ ! -f genesis.spec.json ]; then
        cp ../scripts/genesis.spec.json ./
      fi
      cardano-cli shelley genesis create --genesis-dir . --supply ${toString maxSupply} --gen-genesis-keys ${toString nbCoreNodes} --gen-utxo-keys ${toString nbCoreNodes}
      mkdir -p node-keys
      cd node-keys
      for i in {1..${toString nbCoreNodes}}; do
        cardano-cli shelley node key-gen-VRF --verification-key-file node-vrf$i.vkey --signing-key-file node-vrf$i.skey
        cardano-cli shelley node key-gen-KES --verification-key-file node-kes$i.vkey --signing-key-file node-kes$i.skey
        cardano-cli shelley node issue-op-cert --hot-kes-verification-key-file node-kes$i.vkey --cold-signing-key-file ../delegate-keys/delegate$i.skey --operational-certificate-issue-counter ../delegate-keys/delegate-opcert$i.counter --kes-period 0 --out-file node$i.opcert
      done
    '';
  renew-kes-keys =
    let nbCoreNodes = builtins.length globals.topology.coreNodes;
    in writeShellScriptBin "new-KES-keys-at-period" ''
      set -euxo pipefail
      PERIOD=$1
      cd ${toString ./keys}/node-keys
      for i in {1..${toString nbCoreNodes}}; do
        cardano-cli shelley node key-gen-KES --verification-key-file node-kes$i.vkey --signing-key-file node-kes$i.skey
        cardano-cli shelley node issue-op-cert --hot-kes-verification-key-file node-kes$i.vkey --cold-signing-key-file ../delegate-keys/delegate$i.skey --operational-certificate-issue-counter ../delegate-keys/delegate$i.counter --kes-period $PERIOD --out-file node$i.opcert
      done
    '';
  test-cronjob-script = writeShellScriptBin "test-cronjob-script" ''
      set -euxo pipefail
      PARAM=$1
      cd ${toString ./scripts}
      cardano-cli --version
    '';
in  mkShell {
  buildInputs = [
    cardano-cli
    create-shelley-genesis-and-keys
    dnsutils
    iohkNix.niv
    kes-rotation
    migrate-keys
    mkDevGenesis
    nivOverrides
    nix
    nix-diff
    nixops
    pandoc
    pstree
    relay-update
    renew-kes-keys
    telnet
    test-cronjob-script
  ] ++ (with cardano-sl-pkgs.nix-tools.exes;
          lib.optionals (globals.topology.legacyCoreNodes != [])
          [ cardano-sl-auxx cardano-sl-tools ]);
  NIX_PATH = "nixpkgs=${path}";
  NIXOPS_DEPLOYMENT = "${globals.deploymentName}";
  passthru = {
    gen-graylog-creds = iohk-ops-lib.scripts.gen-graylog-creds { staticPath = ./static; };
  };
}
