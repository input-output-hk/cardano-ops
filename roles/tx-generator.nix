pkgs: { config, name, lib, nodes, resources, ... }:
with pkgs;

let
  # We need first 3 signing keys and delegation certificate
  # to be able to run tx generator and sign generated transactions.
  signingKeyGen = ../keys/delegate-keys.000.key;
  signingKeySrc = ../keys/delegate-keys.001.key;
  signingKeyRec = ../keys/delegate-keys.002.key;
  delegationCertificate = ../keys/delegation-cert.000.json;

  cardanoNodes = lib.filterAttrs
    (_: node: node.config.services.cardano-node.enable or false &&
              ! (node.config.services.cardano-db-sync.enable or false))
    nodes;

  # benchmarking-src = ../../cardano-benchmarking;
  benchmarking-src = sourcePaths.cardano-benchmarking;
in {
  imports = [
    (benchmarking-src + "/nix/nixos/tx-generator-service.nix")
  ];

  services.tx-generator = {
    enable = true;
    targetNodes = __mapAttrs
      (name: node: { ip = getPublicIp resources nodes name;
                     port = node.config.services.cardano-node.port;
                   })
      cardanoNodes;

    ## nodeConfig of the locally running observer node.
    localNodeConf = config.services.cardano-node;
    keyGen = "/var/lib/keys/cardano-node-signing-gen";
    keySrc = "/var/lib/keys/cardano-node-signing-src";
    keyRec = "/var/lib/keys/cardano-node-signing-rec";
    delegCert = "/var/lib/keys/cardano-node-delegation-cert";

    ## The nodeConfig of the Tx generator itself.
    nodeConfig = {
      minSeverity = "Debug";
      TracingVerbosity = "MaximalVerbosity";

      TraceBlockFetchClient             = true;
      TraceBlockFetchDecisions          = false;
      TraceBlockFetchProtocol           = true;
      TraceBlockFetchProtocolSerialised = false;
      TraceBlockFetchServer             = false;
      TraceChainDb                      = true;
      TraceChainSyncClient              = true;
      TraceChainSyncBlockServer         = false;
      TraceChainSyncHeaderServer        = false;
      TraceChainSyncProtocol            = true;
      TraceDNSResolver                  = false;
      TraceDNSSubscription              = false;
      TraceErrorPolicy                  = true;
      TraceForge                        = false;
      TraceIpSubscription               = false;
      TraceLocalChainSyncProtocol       = true;
      TraceLocalTxSubmissionProtocol    = true;
      TraceLocalTxSubmissionServer      = true;
      TraceMempool                      = true;
      TraceMux                          = false;
      TraceTxInbound                    = true;
      TraceTxOutbound                   = true;
      TraceTxSubmissionProtocol         = true;
    };

    dsmPassthrough = {
      # rtsOpts = ["-xc"];
    };
  } // globals.environmentConfig.generatorConfig;

  services.cardano-node = {
    nodeConfig = lib.mkForce (globals.environmentConfig.nodeConfig // {
      defaultScribes = [
        [ "StdoutSK" "stdout" ]
        [ "FileSK"   "/var/lib/cardano-node/logs/node.json" ]
      ];
      setupScribes = [
        { scKind = "StdoutSK"; scName = "stdout"; scFormat = "ScJson"; }
        { scKind = "FileSK"; scName = "/var/lib/cardano-node/logs/node.json"; scFormat = "ScJson";
          scRotation = {
            rpLogLimitBytes = 300000000;
            rpMaxAgeHours   = 24;
            rpKeepFilesNum  = 2;
          }; }
      ];
      minSeverity = "Debug";
      TracingVerbosity = "MaximalVerbosity";

      TraceBlockFetchClient             = true;
      TraceBlockFetchDecisions          = false;
      TraceBlockFetchProtocol           = true;
      TraceBlockFetchProtocolSerialised = false;
      TraceBlockFetchServer             = false;
      TraceChainDb                      = true;
      TraceChainSyncClient              = true;
      TraceChainSyncBlockServer         = false;
      TraceChainSyncHeaderServer        = false;
      TraceChainSyncProtocol            = false;
      TraceDNSResolver                  = false;
      TraceDNSSubscription              = false;
      TraceErrorPolicy                  = true;
      TraceForge                        = false;
      TraceIpSubscription               = false;
      TraceLocalChainSyncProtocol       = false; ## This is horribly noisy!
      TraceLocalTxSubmissionProtocol    = false; ## ..too!
      TraceLocalTxSubmissionServer      = true;
      TraceMempool                      = false; ## Too!
      TraceMux                          = false;
      TraceTxInbound                    = true;
      TraceTxOutbound                   = true;
      TraceTxSubmissionProtocol         = true;

      TurnOnLogMetrics = true;
      options = {
        mapBackends = {
          "cardano.node-metrics" = [ "KatipBK" ];
        };
      };
    });

    signingKey = lib.mkForce "/var/lib/keys/cardano-node-signing-gen";
    delegationCertificate = lib.mkForce "/var/lib/keys/cardano-node-delegation-cert";
  };

  deployment.keys = {
    "cardano-node-signing-gen" = builtins.trace ("${name}: using " + (toString signingKeyGen)) {
        keyFile = signingKeyGen;
        user = "cardano-node";
        group = "cardano-node";
        destDir = "/var/lib/keys";
    };
    "cardano-node-signing-src" = builtins.trace ("${name}: using " + (toString signingKeySrc)) {
        keyFile = signingKeySrc;
        user = "cardano-node";
        group = "cardano-node";
        destDir = "/var/lib/keys";
    };
    "cardano-node-signing-rec" = builtins.trace ("${name}: using " + (toString signingKeyRec)) {
        keyFile = signingKeyRec;
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

  services.cardano-explorer-api.enable = lib.mkForce true;

  users.users.cardano-node.extraGroups = [ "keys" ];
}
