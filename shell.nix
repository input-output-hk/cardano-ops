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
  genesisFile = let
    protocol."Cardano" = globals.environmentConfig.nodeConfig.ByronGenesisFile or "please set globals.environmentName or globals.environmentConfig.genesisFile";
    protocol."RealPBFT" = globals.environmentConfig.nodeConfig.ByronGenesisFile or "please set globals.environmentName or globals.environmentConfig.genesisFile";
    protocol."Byron" = globals.environmentConfig.nodeConfig.ByronGenesisFile or "please set globals.environmentName or globals.environmentConfig.genesisFile";
    protocol."TPraos" = null;
    in protocol.${globals.environmentConfig.nodeConfig.Protocol};

  shelleyGenesis = builtins.fromJSON (builtins.readFile globals.environmentConfig.nodeConfig.ShelleyGenesisFile);

  hoursUntilNextEpoch =
    let inherit (shelleyGenesis) epochLength systemStart;
    in writeShellScriptBin "hoursUntilNextEpoch" ''
        elapsedSeconds=$(( $(date +\%s) - $(date +\%s -d "${systemStart}") ))
        elapsedSecondsInEpoch=$(( $elapsedSeconds % ${toString epochLength} ))
        secondsUntilNextEpoch=$(( ${toString epochLength} - $elapsedSecondsInEpoch ))
        hoursUntilNextEpoch=$(( $secondsUntilNextEpoch / 3600 ))
        echo $hoursUntilNextEpoch
    '';

  var = 21;

  foo =
    writeShellScriptBin "foo" (import ./examples/shelley-testnet/scripts/hello.nix { inherit var pparams; });

  # Protocol parameters
  pparams =
    rec { k = 10;
          f = 0.1;
          epoch-length= (10 * k) / f;
          bftCoreNodes = map (x: x.name) globals.topology.bftCoreNodes;
          stakePoolNodes = map (x: x.name) globals.topology.stakePoolNodes;
        };

  create-shelley-genesis-and-keys =
    let nbCoreNodes = builtins.length globals.topology.coreNodes;
        nbBFTNodes = builtins.length globals.topology.bftCoreNodes;
        nbStakePoolNodes = builtins.length globals.topology.stakePoolNodes;
        maxSupply = 20000000000000000 * nbCoreNodes;
    in writeShellScriptBin "create-shelley-genesis-and-keys" ''
      set -euxo pipefail
      mkdir -p keys
      cd ${toString ./keys}
      cardano-cli shelley genesis create \
                  --genesis-dir . \
                  --supply ${toString maxSupply} \
                  --gen-genesis-keys ${toString nbBFTNodes} \
                  --gen-utxo-keys ${toString nbCoreNodes} \
                  --start-time `date -u -d "today + 10 minutes" +'%Y-%m-%dT%H:%M:%SZ'` \
                  --testnet-magic 42
      # Customize the genesis file
      #
      # We should ensure that:
      #
      #    10 * securityParam / activeSlotsCoeff <= epochLength
      K=10
      F=0.1
      SLOT_LENGTH=0.2
      EPOCH_LENGTH=`perl -E "say ((10 * $K) / $F)"`
      # jq will convert the big nunbers to scientific notation, and old versions of nix cannot handle this. Hence we need to use sed.
      sed -Ei "s/^([[:blank:]]*\"updateQuorum\":)([[:blank:]]*[^,]*,)$/\1 ${toString nbBFTNodes},/" genesis.json
      sed -Ei "s/^([[:blank:]]*\"epochLength\":)([[:blank:]]*[^,]*,)$/\1 $EPOCH_LENGTH,/" genesis.json
      sed -Ei "s/^([[:blank:]]*\"slotLength\":)([[:blank:]]*[^,]*,)$/\1 $SLOT_LENGTH,/" genesis.json
      sed -Ei "s/^([[:blank:]]*\"securityParam\":)([[:blank:]]*[^,]*)$/\1 $K/" genesis.json
      sed -Ei "s/^([[:blank:]]*\"activeSlotsCoeff\":)([[:blank:]]*[^,]*,)$/\1 $F,/" genesis.json

      cardano-cli shelley genesis hash --genesis genesis.json > GENHASH
      mkdir -p node-keys
      cd node-keys
      # Create VRF keys for the BFT nodes.
      for i in {1..${toString nbBFTNodes}}; do
        ln -sf ../delegate-keys/delegate$i.vrf.skey node-vrf$i.skey
        ln -sf ../delegate-keys/delegate$i.vrf.vkey node-vrf$i.vkey
      done
      # Create VRF keys for the pool nodes
      for i in `seq $((${toString nbBFTNodes}+1)) ${toString nbCoreNodes}`; do
        cardano-cli shelley node key-gen-VRF \
                    --verification-key-file node-vrf$i.vkey \
                    --signing-key-file node-vrf$i.skey
      done
      ${renew-kes-keys}/bin/new-KES-keys-at-period 0
    '';
  renew-kes-keys =
    let nbCoreNodes = builtins.length globals.topology.coreNodes;
        nbBFTNodes = builtins.length globals.topology.bftCoreNodes;
    in writeShellScriptBin "new-KES-keys-at-period" ''
      set -euxo pipefail
      PERIOD=$1
      cd ${toString ./keys}/node-keys
      # Generate a KES key pair
      for i in {1..${toString nbCoreNodes}}; do
        cardano-cli shelley node key-gen-KES \
                    --verification-key-file node-kes$i.vkey \
                    --signing-key-file node-kes$i.skey
      done
      # Genereate an operational certificate for the BFT nodes, using the delegate keys as cold signing key.
      for i in {1..${toString nbBFTNodes}}; do
        cardano-cli shelley node issue-op-cert \
                    --hot-kes-verification-key-file node-kes$i.vkey \
                    --cold-signing-key-file ../delegate-keys/delegate$i.skey \
                    --operational-certificate-issue-counter ../delegate-keys/delegate$i.counter \
                    --kes-period $PERIOD \
                    --out-file node$i.opcert
      done
      # For the pool nodes we need to generate the cold keys and the cold counter.
      for i in `seq $((${toString nbBFTNodes}+1)) ${toString nbCoreNodes}`; do
        cardano-cli shelley node key-gen \
            --cold-verification-key-file cold$i.vkey \
            --cold-signing-key-file cold$i.skey \
            --operational-certificate-issue-counter-file cold$i.counter
        cardano-cli shelley node issue-op-cert \
                    --hot-kes-verification-key-file node-kes$i.vkey \
                    --cold-signing-key-file cold$i.skey \
                    --operational-certificate-issue-counter cold$i.counter \
                    --kes-period $PERIOD \
                    --out-file node$i.opcert
      done
    '';
  test-cronjob-script = writeShellScriptBin "test-cronjob-script" ''
      set -euxo pipefail
      PARAM=$1
      cd ${toString ./scripts}
      cardano-cli --version
    '';
in  mkShell rec {
  buildInputs = [
    awscli2
    bashInteractive
    cardano-cli
    dnsutils
    iohkNix.niv
    nivOverrides
    nix
    nix-diff
    nixops
    pandoc
    pstree
    telnet
    test-cronjob-script
    cardano-ping
    hoursUntilNextEpoch
    relayUpdateTimer
  ] ++ (lib.optional pkgs.stdenv.hostPlatform.isLinux ([
    # Those fail to compile under macOS:
    node-update
    # scripts NOT for use on mainnet:
  ] ++ lib.optionals (globals.environmentName != "mainnet") kes-rotation)
  ) ++ (lib.optionals (globals.environmentName != "mainnet") [ 
    renew-kes-keys
    create-shelley-genesis-and-keys
  ]);
  # If any build input has bash completions, add it to the search
  # path for shell completions.
  XDG_DATA_DIRS = lib.concatStringsSep ":" (
    [(builtins.getEnv "XDG_DATA_DIRS")] ++
    (lib.filter
      (share: builtins.pathExists (share + "/bash-completion"))
      (map (p: p + "/share") buildInputs))
  );
  
  BFT_NODES = map (x: x.name) globals.topology.bftCoreNodes;
  POOL_NODES = map (x: x.name) globals.topology.stakePoolNodes;
  # Network parameters.
  K = 10;            # Security parameter
  F = 0.1;           # Active slot coefficient
  SLOT_LENGTH = 0.2;
  MAX_SUPPLY = 20000000000000000 * builtins.length globals.topology.coreNodes;
  # End: Network parameters.
  
  NIX_PATH = "nixpkgs=${path}";
  NIXOPS_DEPLOYMENT = "${globals.deploymentName}";
  passthru = {
    gen-graylog-creds = iohk-ops-lib.scripts.gen-graylog-creds { staticPath = ./static; };
  };
}
