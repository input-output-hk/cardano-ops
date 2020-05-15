
pkgs: {config, name, ...}:
with pkgs;
let
  nodeId = config.node.nodeId;
  leftPad = number: width: lib.fixedWidthString width "0" (toString number);
  signingKey = ../keys/delegate-keys + ".${leftPad nodeId 3}.key";
  delegationCertificate = ../keys/delegation-cert + ".${leftPad nodeId 3}.json";

in {

  imports = [
    cardano-ops.modules.base-service
  ];

  services.cardano-node = {
    signingKey = "/var/lib/keys/cardano-node-signing";
    delegationCertificate = "/var/lib/keys/cardano-node-delegation-cert";
    nodeConfig = globals.environmentConfig.nodeConfig // {
      defaultScribes = [
        [ "StdoutSK" "stdout" ]
        [ "FileSK"   "/var/lib/cardano-node/logs/node.json" ]
      ];
      setupScribes = [
        { scKind = "StdoutSK"; scName = "stdout"; scFormat = "ScJson"; }
        { scKind = "FileSK"; scName = "/var/lib/cardano-node/logs/node.json"; scFormat = "ScJson"; "scRotation" = null; }
      ];
      minSeverity = "Debug";
      TracingVerbosity = "MaximalVerbosity";

      # TraceBlockFetchClient = true;
      # TraceBlockFetchDecisions = false;
      # TraceBlockFetchProtocol = false;
      # TraceBlockFetchProtocolSerialised = false;
      # TraceBlockFetchServer = false;
      # TraceChainDb = true;
      # TraceChainSyncClient = false;
      # TraceChainSyncBlockServer = false;
      # TraceChainSyncHeaderServer = false;
      # TraceChainSyncProtocol = false;
      # TraceDNSResolver = false;
      # TraceDNSSubscription = false;
      # TraceErrorPolicy = false;
      # TraceForge = false;
      # TraceIpSubscription = false;
      # TraceLocalChainSyncProtocol = false;
      # TraceLocalTxSubmissionProtocol = false;
      # TraceLocalTxSubmissionServer = false;
      # TraceMempool = true;
      # TraceMux = false;
      # TraceTxInbound = true;
      # TraceTxOutbound = true;
      # TraceTxSubmissionProtocol = true;

      TurnOnLogMetrics = false;
    };
  };

  systemd.services."cardano-node" = {
    after = [ "cardano-node-signing-key.service" "cardano-node-delegation-cert-key.service" ];
    wants = [ "cardano-node-signing-key.service" "cardano-node-delegation-cert-key.service" ];
  };

  users.users.cardano-node.extraGroups = [ "keys" ];

  deployment.keys = {
    "cardano-node-signing" = builtins.trace ("${name}: using " + (toString signingKey)) {
        keyFile = signingKey;
        user = "cardano-node";
        group = "cardano-node";
        destDir = "/var/lib/keys";
    };
    "cardano-node-delegation-cert" = builtins.trace ("${name}: using " + (toString delegationCertificate)) {
        keyFile = delegationCertificate;
        user = "cardano-node";
        group = "cardano-node";
        destDir = "/var/lib/keys";
    };
  };

}
