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

  create-shelley-genesis-and-keys =
    let nbCoreNodes = builtins.length globals.topology.coreNodes;
        maxSupply = 20000000000000000 * nbCoreNodes;
    in writeShellScriptBin "create-shelley-genesis-and-keys" ''
      set -euxo pipefail
      mkdir -p keys
      cd ${toString ./keys}
      cardano-cli shelley genesis create --genesis-dir . --supply ${toString maxSupply} --gen-genesis-keys ${toString nbCoreNodes} --gen-utxo-keys ${toString nbCoreNodes} --testnet-magic 42
      cardano-cli shelley genesis hash --genesis genesis.json > GENHASH
      mkdir -p node-keys
      cd node-keys
      for i in {1..${toString nbCoreNodes}}; do
        ln -sf ../delegate-keys/delegate$i.vrf.skey node-vrf$i.skey
        ln -sf ../delegate-keys/delegate$i.vrf.vkey node-vrf$i.vkey
      done
      ${renew-kes-keys}/bin/new-KES-keys-at-period 0
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
in  mkShell rec {
  buildInputs = [
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
    node-update
    telnet
    test-cronjob-script
    cardano-cli-completions
    cardano-ping
    hoursUntilNextEpoch
    relayUpdateTimer
  ] ++ (lib.optionals (globals.environmentName != "mainnet") [
    # scripts NOT for use on mainnet:
    kes-rotation
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
  NIX_PATH = "nixpkgs=${path}";
  NIXOPS_DEPLOYMENT = "${globals.deploymentName}";
  passthru = {
    gen-graylog-creds = iohk-ops-lib.scripts.gen-graylog-creds { staticPath = ./static; };
  };

}
