# This derivation assumes a toplogy file where the following attributes are
# defined:
#
# - bftCoreNodes
# - stakePoolNodes
# - coreNodes
#
{ config ? {}
, pkgs ? import ./nix {
    inherit config;
  }
}:
with pkgs; with lib;
let
  nivOverrides = writeShellScriptBin "niv-overrides" ''
    niv --sources-file ${toString globals.sourcesJsonOverride} $@
  '';

in  mkShell (rec {
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
    perl
    pstree
    telnet
    cardano-ping
    relayUpdateTimer
  ] ++ (lib.optionals pkgs.stdenv.hostPlatform.isLinux ([
    # Those fail to compile under macOS:
    node-update
    # script NOT for use on mainnet:
  ] ++ lib.optional (globals.environmentName != "mainnet") kes-rotation));
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
} // lib.optionalAttrs (builtins.pathExists ./globals.nix) (let
  genesisFile = globals.environmentConfig.nodeConfig.ShelleyGenesisFile;
  genesis = builtins.fromJSON (builtins.readFile genesisFile);
  in rec {
  ENVIRONMENT = globals.environmentName;

  CORE_NODES = map (x: x.name) globals.topology.coreNodes;
  NB_CORE_NODES = builtins.length CORE_NODES;
  BFT_NODES = map (x: x.name) (filter (c: !c.stakePool) globals.topology.coreNodes);
  NB_BFT_NODES = builtins.length BFT_NODES;
  POOL_NODES = map (x: x.name) (filter (c: c.stakePool) globals.topology.coreNodes);
  NB_POOL_NODES = builtins.length POOL_NODES;

  GENESIS_PATH = genesisFile;
  # Network parameters.
  SYSTEM_START = genesis.systemStart;
  EPOCH_LENGTH = toString genesis.epochLength;
  SLOT_LENGTH = toString genesis.slotLength;
  K = toString genesis.securityParam;
  F = toString genesis.activeSlotsCoeff;
  MAX_SUPPLY = toString genesis.maxLovelaceSupply;
  # End: Network parameters.
}))
