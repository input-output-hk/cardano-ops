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
