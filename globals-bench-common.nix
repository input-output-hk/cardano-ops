{ pkgs, benchmarkingProfile }:

with pkgs.lib;
rec {
  mkNodeOverlay =
    machineOverlay: nodeConfigOverlay:
    recursiveUpdate
    {
      documentation = {
        man.enable = false;
        doc.enable = false;
      };
      networking.firewall.allowPing = mkForce true;
      services.cardano-node = {
        eventlog = mkForce true;
        extraNodeConfig = mkExtraNodeConfig nodeConfigOverlay;
        package = mkForce pkgs.cardano-node-eventlogged;
        rtsArgs =
          mkForce ([ "-N2" "-A16m" "-qg" "-qb" "-scardano-node.gcstats" ]
                   ++
                   (benchmarkingProfile.node.rts_flags_override or []));
        useNewTopology = benchmarkingProfile.node.p2p or false;
        usePeersFromLedgerAfterSlot = if benchmarkingProfile.node.useLedgerPeers then 0 else -1;
      };
    } machineOverlay;

  mkExtraNodeConfig =
    { TraceBlockFetchProtocol ? false
    , ... }@cfgOverlay:
    recursiveUpdate
      (removeAttrs pkgs.globals.environmentConfig.nodeConfig
        ["ByronGenesisHash"
         "ShelleyGenesisHash"
         "AlonzoGenesisHash"
         "ConwayGenesisHash"])
      (recursiveUpdate
        (benchmarkingLogConfig "node")
        ({
           TracingVerbosity = "NormalVerbosity";
           minSeverity = "Debug";
           TurnOnLogMetrics = true;

           ExperimentalHardForksEnabled = true;
           # ExperimentalProtocolsEnabled = true;
           # TestEnableDevelopmentHardForkEras = true;
           # TestEnableDevelopmentNetworkProtocols = true;

           ChainSyncIdleTimeout = 0;

           inherit TraceBlockFetchProtocol;

           TraceMempool               = true;
           TraceTxInbound             = true;
           TraceBlockFetchClient      = true;
           TraceBlockFetchServer      = true;
           TraceChainSyncHeaderServer = true;
           TraceChainSyncClient       = true;
           TraceBackingStore          = false;
        } //
        (benchmarkingProfile.node.extra_config or {})
        // cfgOverlay));

  benchmarkingLogConfig = name: {
    defaultScribes = [
      [ "StdoutSK" "stdout" ]
      [ "FileSK"   "logs/${name}.json" ]
    ];
    setupScribes = [
      {
        scKind     = "StdoutSK";
        scName     = "stdout";
        scFormat   = "ScJson"; }
      {
        scKind     = "FileSK";
        scName     = "logs/${name}.json";
        scFormat   = "ScJson";
        scRotation = {
          ## 1. Twice-daily, so not too large, but also most benchmarks
          ##    would be covered by that
          rpMaxAgeHours   = 12;
          ## 2. Ten per epoch, for two last epochs
          rpKeepFilesNum  = 20;
          ## 3. 10GB/file to prevent file-size cutoff from happening,
          ##    and so most benchmarks will have just 1 file
          rpLogLimitBytes = 10*1000*1000*1000;
        }; }
    ];
    options = {
      mapBackends = {
        "cardano.node.resources" = [ "KatipBK" ];
        "cardano.node.metrics"   = [ "EKGViewBK" ];
      };
    };
  };
}
