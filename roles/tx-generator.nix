pkgs: { config, name, lib, nodes, resources, ... }:
with pkgs;

let
  inherit (globals.environmentConfig.networkConfig) Protocol;

  # We need a signing key with access to funds
  # to be able to run tx generator and sign generated transactions.
  signingKey =
    { TPraos   = ../keys/utxo-keys/utxo1.skey;
      RealPBft = ../keys/delegate-keys.000.key;
    }."${Protocol}"
      or (abort "Unsupported protocol: ${Protocol}");

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
    sigKey = "/var/lib/keys/cardano-node-signing";

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
      TraceMempool                      = false;
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

    signingKey = lib.mkForce "/var/lib/keys/cardano-node-signing";
  };

  deployment.keys = {
    "cardano-node-signing" = builtins.trace ("${name}: using " + (toString signingKey)) {
        keyFile = signingKey;
        user = "cardano-node";
        group = "cardano-node";
        destDir = "/var/lib/keys";
    };
  };

  # services.cardano-explorer-api.enable = lib.mkForce false;
  # services.cardano-db-sync.enable      = lib.mkForce false;
  # services.cardano-graphql.enable      = lib.mkForce false;
  # services.cardano-postgres.enable     = lib.mkForce false;
  # services.cardano-submit-api.enable   = lib.mkForce false;
  # services.graphql-engine.enable       = lib.mkForce false;
  # services.postgresql.enable           = lib.mkForce false;
  # services.nginx.enable                = lib.mkForce false;

  users.users.cardano-node.extraGroups = [ "keys" ];
}
