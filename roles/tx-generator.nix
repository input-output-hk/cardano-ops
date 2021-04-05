pkgs: { config, name, lib, nodes, resources, ... }:
with pkgs;

let
  inherit (globals.environmentConfig.networkConfig) Protocol;

  # We need a signing key with access to funds
  # to be able to run tx generator and sign generated transactions.
  signingKey =
    { Cardano  = ../keys/utxo-keys/utxo1.skey;
      TPraos   = ../keys/utxo-keys/utxo1.skey;
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
      (name: node:
        { ip   = let ip = getPublicIp resources nodes name;
                 in __trace "generator target:  ${name}/${ip}" ip;
          port = node.config.services.cardano-node.port;
        })
      (lib.filterAttrs
        (_: n: ! (n.config.node.roles.isExplorer))
        cardanoNodes);

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

      defaultScribes = [
        [ "StdoutSK" "stdout" ]
        [ "FileSK"   "logs/generator.json" ]
      ];
      setupScribes = [
        { scKind = "StdoutSK"; scName = "stdout"; scFormat = "ScJson"; }
        { scKind = "FileSK"; scName = "logs/generator.json"; scFormat = "ScJson";
          scRotation = {
            rpLogLimitBytes = 300000000;
            rpMaxAgeHours   = 24;
            rpKeepFilesNum  = 20;
          }; }
      ];
    };

    dsmPassthrough = {
      # rtsOpts = ["-xc"];
    };
  } // globals.environmentConfig.generatorConfig;

  services.cardano-node = {
    nodeConfig = lib.mkForce (globals.environmentConfig.nodeConfig // {
      defaultScribes = [
        [ "StdoutSK" "stdout" ]
        [ "FileSK"   "logs/node.json" ]
      ];
      setupScribes = [
        { scKind = "StdoutSK"; scName = "stdout"; scFormat = "ScJson"; }
        { scKind = "FileSK"; scName = "logs/node.json"; scFormat = "ScJson";
          scRotation = {
            rpLogLimitBytes = 300000000;
            rpMaxAgeHours   = 24;
            rpKeepFilesNum  = 20;
          }; }
      ];
      minSeverity = "Debug";
      TracingVerbosity = "NormalVerbosity";

      TraceAcceptPolicy                 = false;
      TraceBlockFetchClient             = true;
      TraceBlockFetchDecisions          = false;
      TraceBlockFetchProtocol           = true;
      TraceBlockFetchProtocolSerialised = false;
      TraceBlockFetchServer             = false;
      TraceBlockchainTime               = false;
      TraceChainDB                      = true;
      TraceChainSyncBlockServer         = false;
      TraceChainSyncClient              = true;
      TraceChainSyncHeaderServer        = false;
      TraceChainSyncProtocol            = false;
      TraceDiffusionInitialization      = false;
      TraceDnsResolver                  = false;
      TraceDnsSubscription              = false;
      TraceErrorPolicy                  = true;
      TraceForge                        = false;
      TraceForgeStateInfo               = false;
      TraceHandshake                    = false;
      TraceIpSubscription               = false;
      TraceKeepAliveClient              = false;
      TraceLocalChainSyncProtocol       = false;
      TraceLocalErrorPolicy             = false;
      TraceLocalHandshake               = false;
      TraceLocalStateQueryProtocol      = false;
      TraceLocalTxSubmissionProtocol    = true;
      TraceLocalTxSubmissionServer      = true;
      TraceMempool                      = true;
      TraceMux                          = true;
      TraceTxInbound                    = true;
      TraceTxOutbound                   = true;
      TraceTxSubmissionProtocol         = true;
      TraceTxSubmission2Protocol        = true;

      TurnOnLogMetrics = true;
      options = {
        mapBackends = {
          "cardano.node.resources" = [ "KatipBK" ];
        };
      };
    } //
    ({
      shelley =
        { TestShelleyHardForkAtEpoch = 0;
        };
      allegra =
        { TestShelleyHardForkAtEpoch = 0;
          TestAllegraHardForkAtEpoch = 0;
        };
      mary =
        { TestShelleyHardForkAtEpoch = 0;
          TestAllegraHardForkAtEpoch = 0;
          TestMaryHardForkAtEpoch = 0;
        };
    }).${globals.environmentConfig.generatorConfig.era});
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
