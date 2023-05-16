pkgs: { config, options, name, nodes, resources, ... }:
let
  lib = pkgs.lib;
  cfg = config.services.custom-metrics;
  cfgExporters = config.services.monitoring-exporters;
  cfgNode = config.services.cardano-node;
  inherit (lib) mkIf mkOption types;
in with pkgs; {
  options = {
    services.custom-metrics = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Allow for custom metrics collection using either node statsd exporter or netdata.
        '';
      };

      enableNetdata = mkOption {
        type = types.bool;
        default = if (cfg.statsdExporter == "node") then false else true;
        description = ''
          Even if netdata is not used for the statsd metrics, is can be enabled for use.
        '';
      };

      statsdExporter = mkOption {
        type = types.enum [ "node" "netdata" ];
        default = if cfgExporters.metrics then "node" else "netdata";
        description = ''
          The default node exporter to use.  If "node" is selected, it is assumed to be
          already configured as part of the monitoring-exporters ops-lib module.  If netdata
          is selected it will be installed via this module
        '';
      };

      netdataStatsdPort = mkOption {
        type = types.int;
        default = 8126;
        description = ''
          The default statsd listening port for netdata.  It defaults to 8125 to avoid
          colliding with the node exporter at 8125, if enabled.
        '';
      };

      opcertFile = mkOption {
        type = types.str;
        default = "/var/lib/keys/cardano-node-operational-cert";
        description = "The file (with absolute path) for the cardano-node opcert on the deployer server.";
      };

      testnetMagicNumber = mkOption {
        type = types.int;
        default = (__fromJSON (__readFile globals.environmentConfig.nodeConfig.ShelleyGenesisFile)).networkMagic;
        description = "The testnet magic number";
      };

      useTestnetMagic = mkOption {
        type = types.bool;
        default = if globals.environmentName != "mainnet" then true else false;
        description = "Whether to use testnet magic (required for testnets)";
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [{
      assertion = !(cfg.statsdExporter == "netdata" && cfg.enableNetdata == false);
      message = "enableNetdata must be `true` if statsdExporter is `netdata`";
    }];

    # This will set iptables for netdata; security groups are already handled at the globals level
    # where extraPrometheusExporterPorts are defined
    networking.firewall.allowedTCPPorts = mkIf (cfg.enableNetdata || cfg.statsdExporter == "netdata")
      [ globals.netdataExporterPort ];
    services.netdata = mkIf (cfg.enableNetdata || cfg.statsdExporter == "netdata") {
      enable = true;
      config = {
        global = {
          "default port" = "19999";
          "bind to" = "*";
          "history" = "86400";
          "error log" = "syslog";
          "debug log" = "syslog";
        };
        plugins = {
          "tc" = "no";
          "idlejitter" = "no";
          "cgroups" = "no";
          "checks" = "no";
          "apps" = "no";
          "charts.d" = "no";
          "node.d" = "no";
          "python.d" = "no";
        };
        statsd = {
          "default port" = "${toString cfg.netdataStatsdPort}";
        };
        "plugin:proc" = {
          "/proc/interrupts" = "no";
          "/proc/softirqs" = "no";
        };
      };
    };
    systemd.services.custom-metrics = {
      path = with pkgs; with cfgNode.cardanoNodePkgs; [ cardano-cli coreutils gawk gnugrep gnused jq nmap procps ];
      environment = config.environment.variables;
      script = ''
        STATSD_HOST="localhost"
        STATSD_PORT="${if (cfg.statsdExporter == "node") then (toString cfgExporters.statsdPort) else (toString cfg.netdataStatsdPort)}"

        MAGIC="${if cfg.useTestnetMagic then "--testnet-magic ${toString cfg.testnetMagicNumber}" else "--mainnet"}"
        OPCERT="${cfg.opcertFile}"

        # Default decoded metric settings in case they are not obtainable
        CERT_ISSUE_NUM="-1"
        KES_CREATED_PERIOD="-1"

        # Default genesis metric settings in case they are not obtainable
        ACTIVE_SLOTS_COEFF="-1"
        EPOCH_LENGTH="-1"
        MAX_KES_EVOLUTIONS="-1"
        SECURITY_PARAM="-1"
        SLOTS_PER_KES_PERIOD="-1"
        SLOT_LENGTH="-1"

        # Default protocol metric settings in case they are not obtainable
        A_0="-1"
        DECENTRALISATION_PARAM="-1"
        E_MAX="-1"
        KEY_DECAY_RATE="-1"
        KEY_DEPOSIT="-1"
        KEY_MIN_REFUND="-1"
        MAX_BLOCK_BODY_SIZE="-1"
        MAX_BLOCK_HEADER_SIZE="-1"
        MAX_TX_SIZE="-1"
        MIN_FEE_A="-1"
        MIN_FEE_B="-1"
        MIN_UTXO_VALUE="-1"
        N_OPT="-1"
        POOL_DECAY_RATE="-1"
        POOL_DEPOSIT="-1"
        POOL_MIN_REFUND="-1"
        PROTOCOL_VERSION_MINOR="-1"
        PROTOCOL_VERSION_MAJOR="-1"
        RHO="-1"
        TAU="-1"

        # Default protocol and era metrics
        IS_BYRON="-1"
        IS_SHELLEY="-1"
        IS_CARDANO="-1"
        LAST_KNOWN_BLOCK_VERSION_MAJOR="-1"
        LAST_KNOWN_BLOCK_VERSION_MINOR="-1"
        LAST_KNOWN_BLOCK_VERSION_ALT="-1"

        # Default cardano-cli versioning
        CARDANO_CLI_VERSION_MAJOR="-1"
        CARDANO_CLI_VERSION_MINOR="-1"
        CARDANO_CLI_VERSION_PATCH="-1"

        # Default cardano-cli ping metrics
        CARDANO_PING_LATENCY="-1"

        statsd() {
          local UDP="-u" ALL="''${*}"
          echo "Pushing statsd metrics to port: $STATSD_PORT; udp=$UDP"
          # If the string length of all parameters given is above 1000, use TCP
          [ "''${#ALL}" -gt 1000 ] && UDP=
          while [ -n "''${1}" ]; do
            printf "%s\n" "''${1}"
            shift
          done | ncat "''${UDP}" --send-only ''${STATSD_HOST} ''${STATSD_PORT} || return 1

          return 0
        }

        protocol_params() {
          cardano-cli query protocol-parameters $MAGIC
        }

        # main
        #
        if VERSION_OUTPUT=$(cardano-cli version); then
          VERSION=$(echo $VERSION_OUTPUT | head -n 1 | cut -f 2 -d " ")
          CARDANO_CLI_VERSION_MAJOR=$(echo $VERSION | cut -f 1 -d ".")
          CARDANO_CLI_VERSION_MINOR=$(echo $VERSION | cut -f 2 -d ".")
          CARDANO_CLI_VERSION_PATCH=$(echo $VERSION | cut -f 3 -d ".")
        fi

        if CONFIG=$(pgrep -a cardano-node | grep -oP ".*--config \K.*-${toString cfgNode.nodeId}-0\.json"); then
          echo "Cardano node config file is: $CONFIG"
          PROTOCOL=$(jq -r '.Protocol' < "$CONFIG")
          LAST_KNOWN_BLOCK_VERSION_MAJOR=$(jq -r '."LastKnownBlockVersion-Major"'  < "$CONFIG")
          LAST_KNOWN_BLOCK_VERSION_MINOR=$(jq -r '."LastKnownBlockVersion-Minor"'  < "$CONFIG")
          LAST_KNOWN_BLOCK_VERSION_ALT=$(jq -r '."LastKnownBlockVersion-Alt"'  < "$CONFIG")
          if [ "$PROTOCOL" = "Cardano" ]; then
            IS_CARDANO="1"
            GENESIS=$(jq -r '.ShelleyGenesisFile' < "$CONFIG")
            MODE="--cardano-mode"
            if protocol_params; then
              IS_SHELLEY="1"
              IS_BYRON="0"
            else
              IS_SHELLEY="0"
              IS_BYRON="1"
            fi
          elif [ "$PROTOCOL" = "TPraos" ]; then
            IS_SHELLEY="1"
            IS_CARDANO="0"
            GENESIS=$(jq -r '.GenesisFile' < "$CONFIG")
            MODE="--shelley-mode"
          elif [ "$PROTOCOL" = "RealPBFT" ]; then
            echo "Byron era not supported" && exit 1
          else
            echo "Unknown protocol: $PROTOCOL" && exit 1
          fi
          echo "Cardano node shelley genesis file is: $GENESIS"
          if [ -f "$GENESIS" ]; then
            if [ "$IS_SHELLEY" = "1" ]; then
              ACTIVE_SLOTS_COEFF=$(jq '.activeSlotsCoeff' < "$GENESIS")
            else
              ACTIVE_SLOTS_COEFF="1"
            fi
            EPOCH_LENGTH=$(jq '.epochLength' < "$GENESIS")
            SLOTS_PER_KES_PERIOD=$(jq '.slotsPerKESPeriod' < "$GENESIS")
            SLOT_LENGTH=$(jq '.slotLength' < "$GENESIS")
            MAX_KES_EVOLUTIONS=$(jq '.maxKESEvolutions' < "$GENESIS")
            SECURITY_PARAM=$(jq '.securityParam' < "$GENESIS")
          fi
        fi

        if [ -f "$OPCERT" ]; then
          echo "Cardano node opcert file is: $OPCERT"
          DECODED=$(cardano-cli text-view decode-cbor --in-file "$OPCERT")
          CERT_ISSUE_NUM=$(sed '7q;d' <<< "$DECODED" | awk -F '[()]' '{print $2}')
          KES_CREATED_PERIOD=$(sed '8q;d' <<< "$DECODED" | awk -F '[()]' '{print $2}')
        fi

        if PROTOCOL_CONFIG=$(protocol_params); then
          A_0=$(jq '.a0' <<< "$PROTOCOL_CONFIG")
          DECENTRALISATION_PARAM=$(jq '.decentralization' <<< "$PROTOCOL_CONFIG")
          E_MAX=$(jq '.eMax' <<< "$PROTOCOL_CONFIG")
          KEY_DECAY_RATE=$(jq '.keyDecayRate' <<< "$PROTOCOL_CONFIG")
          KEY_DEPOSIT=$(jq '.keyDeposit' <<< "$PROTOCOL_CONFIG")
          KEY_MIN_REFUND=$(jq '.keyMinRefund' <<< "$PROTOCOL_CONFIG")
          MAX_BLOCK_BODY_SIZE=$(jq '.maxBlockBodySize' <<< "$PROTOCOL_CONFIG")
          MAX_BLOCK_HEADER_SIZE=$(jq '.maxBlockHeaderSize' <<< "$PROTOCOL_CONFIG")
          MAX_TX_SIZE=$(jq '.maxTxSize' <<< "$PROTOCOL_CONFIG")
          MIN_FEE_A=$(jq '.minFeeA' <<< "$PROTOCOL_CONFIG")
          MIN_FEE_B=$(jq '.minFeeB' <<< "$PROTOCOL_CONFIG")
          MIN_UTXO_VALUE=$(jq '.minUTxOValue' <<< "$PROTOCOL_CONFIG")
          N_OPT=$(jq '.nOpt' <<< "$PROTOCOL_CONFIG")
          POOL_DECAY_RATE=$(jq '.poolDecayRate' <<< "$PROTOCOL_CONFIG")
          POOL_DEPOSIT=$(jq '.poolDeposit' <<< "$PROTOCOL_CONFIG")
          POOL_MIN_REFUND=$(jq '.poolMinRefund' <<< "$PROTOCOL_CONFIG")
          PROTOCOL_VERSION_MINOR=$(jq '.protocolVersion.minor' <<< "$PROTOCOL_CONFIG")
          PROTOCOL_VERSION_MAJOR=$(jq '.protocolVersion.major' <<< "$PROTOCOL_CONFIG")
          RHO=$(jq '.rho' <<< "$PROTOCOL_CONFIG")
          TAU=$(jq '.tau' <<< "$PROTOCOL_CONFIG")
        fi

        if CARDANO_PING_OUPUT=$(cardano-cli ping --count=1 --host=${cfgNode.hostAddr} --port=${toString cfgNode.port} --magic=$NETWORK_MAGIC --quiet --json); then
          CARDANO_PING_LATENCY=$(jq '.pongs[-1].sample * 1000' <<< "$CARDANO_PING_OUPUT")
        fi


        echo "cardano_node_decode_certIssueNum:''${CERT_ISSUE_NUM}|g"
        echo "cardano_node_decode_kesCreatedPeriod:''${KES_CREATED_PERIOD}|g"

        echo "cardano_node_genesis_activeSlotsCoeff:''${ACTIVE_SLOTS_COEFF}|g"
        echo "cardano_node_genesis_epochLength:''${EPOCH_LENGTH}|g"
        echo "cardano_node_genesis_maxKESEvolutions:''${MAX_KES_EVOLUTIONS}|g"
        echo "cardano_node_genesis_securityParam:''${SECURITY_PARAM}|g"
        echo "cardano_node_genesis_slotLength:''${SLOT_LENGTH}|g"
        echo "cardano_node_genesis_slotsPerKESPeriod:''${SLOTS_PER_KES_PERIOD}|g"

        echo "cardano_node_protocol_a0:''${A_0}|g"
        echo "cardano_node_protocol_decentralisationParam:''${DECENTRALISATION_PARAM}|g"
        echo "cardano_node_protocol_eMax:''${E_MAX}|g"
        echo "cardano_node_protocol_keyDecayRate:''${KEY_DECAY_RATE}|g"
        echo "cardano_node_protocol_keyDeposit:''${KEY_DEPOSIT}|g"
        echo "cardano_node_protocol_keyMinRefund:''${KEY_MIN_REFUND}|g"
        echo "cardano_node_protocol_maxBlockBodySize:''${MAX_BLOCK_BODY_SIZE}|g"
        echo "cardano_node_protocol_maxBlockHeaderSize:''${MAX_BLOCK_HEADER_SIZE}|g"
        echo "cardano_node_protocol_maxTxSize:''${MAX_TX_SIZE}|g"
        echo "cardano_node_protocol_minFeeA:''${MIN_FEE_A}|g"
        echo "cardano_node_protocol_minFeeB:''${MIN_FEE_B}|g"
        echo "cardano_node_protocol_minUTxOValue:''${MIN_UTXO_VALUE}|g"
        echo "cardano_node_protocol_nOpt:''${N_OPT}|g"
        echo "cardano_node_protocol_poolDecayRate:''${POOL_DECAY_RATE}|g"
        echo "cardano_node_protocol_poolDeposit:''${POOL_DEPOSIT}|g"
        echo "cardano_node_protocol_poolMinRefund:''${POOL_MIN_REFUND}|g"
        echo "cardano_node_protocol_protocolVersion_minor:''${PROTOCOL_VERSION_MINOR}|g"
        echo "cardano_node_protocol_protocolVersion_major:''${PROTOCOL_VERSION_MAJOR}|g"
        echo "cardano_node_protocol_rho:''${RHO}|g"
        echo "cardano_node_protocol_tau:''${TAU}|g"

        echo "cardano_node_config_isByron:''${IS_BYRON}|g"
        echo "cardano_node_config_isShelley:''${IS_SHELLEY}|g"
        echo "cardano_node_config_isCardano:''${IS_CARDANO}|g"
        echo "cardano_node_config_lastKnownBlockVersionMajor:''${LAST_KNOWN_BLOCK_VERSION_MAJOR}|g"
        echo "cardano_node_config_lastKnownBlockVersionMinor:''${LAST_KNOWN_BLOCK_VERSION_MINOR}|g"
        echo "cardano_node_config_lastKnownBlockVersionAlt:''${LAST_KNOWN_BLOCK_VERSION_ALT}|g"

        echo "cardano_node_cli_version_major:''${CARDANO_CLI_VERSION_MAJOR}|g"
        echo "cardano_node_cli_version_minor:''${CARDANO_CLI_VERSION_MINOR}|g"
        echo "cardano_node_cli_version_patch:''${CARDANO_CLI_VERSION_PATCH}|g"

        echo "cardano_ping_latency_ms:''${CARDANO_PING_LATENCY}|g"

        statsd \
          "cardano_node_decode_certIssueNum:''${CERT_ISSUE_NUM}|g" \
          "cardano_node_decode_kesCreatedPeriod:''${KES_CREATED_PERIOD}|g" \
          "cardano_node_genesis_activeSlotsCoeff:''${ACTIVE_SLOTS_COEFF}|g" \
          "cardano_node_genesis_epochLength:''${EPOCH_LENGTH}|g" \
          "cardano_node_genesis_maxKESEvolutions:''${MAX_KES_EVOLUTIONS}|g" \
          "cardano_node_genesis_securityParam:''${SECURITY_PARAM}|g" \
          "cardano_node_genesis_slotLength:''${SLOT_LENGTH}|g" \
          "cardano_node_genesis_slotsPerKESPeriod:''${SLOTS_PER_KES_PERIOD}|g"

        statsd \
          "cardano_node_protocol_a0:''${A_0}|g" \
          "cardano_node_protocol_decentralisationParam:''${DECENTRALISATION_PARAM}|g" \
          "cardano_node_protocol_eMax:''${E_MAX}|g" \
          "cardano_node_protocol_keyDecayRate:''${KEY_DECAY_RATE}|g" \
          "cardano_node_protocol_keyDeposit:''${KEY_DEPOSIT}|g" \
          "cardano_node_protocol_keyMinRefund:''${KEY_MIN_REFUND}|g" \
          "cardano_node_protocol_maxBlockBodySize:''${MAX_BLOCK_BODY_SIZE}|g" \
          "cardano_node_protocol_maxBlockHeaderSize:''${MAX_BLOCK_HEADER_SIZE}|g" \
          "cardano_node_protocol_maxTxSize:''${MAX_TX_SIZE}|g" \
          "cardano_node_protocol_minFeeA:''${MIN_FEE_A}|g" \
          "cardano_node_protocol_minFeeB:''${MIN_FEE_B}|g"

        statsd \
          "cardano_node_protocol_minUTxOValue:''${MIN_UTXO_VALUE}|g" \
          "cardano_node_protocol_nOpt:''${N_OPT}|g" \
          "cardano_node_protocol_poolDecayRate:''${POOL_DECAY_RATE}|g" \
          "cardano_node_protocol_poolDeposit:''${POOL_DEPOSIT}|g" \
          "cardano_node_protocol_poolMinRefund:''${POOL_MIN_REFUND}|g" \
          "cardano_node_protocol_protocolVersion_minor:''${PROTOCOL_VERSION_MINOR}|g" \
          "cardano_node_protocol_protocolVersion_major:''${PROTOCOL_VERSION_MAJOR}|g" \
          "cardano_node_protocol_rho:''${RHO}|g" \
          "cardano_node_protocol_tau:''${TAU}|g"

        statsd \
          "cardano_node_config_isByron:''${IS_BYRON}|g" \
          "cardano_node_config_isShelley:''${IS_SHELLEY}|g" \
          "cardano_node_config_isCardano:''${IS_CARDANO}|g" \
          "cardano_node_config_lastKnownBlockVersionMajor:''${LAST_KNOWN_BLOCK_VERSION_MAJOR}|g" \
          "cardano_node_config_lastKnownBlockVersionMinor:''${LAST_KNOWN_BLOCK_VERSION_MINOR}|g" \
          "cardano_node_config_lastKnownBlockVersionAlt:''${LAST_KNOWN_BLOCK_VERSION_ALT}|g" \
          "cardano_node_cli_version_major:''${CARDANO_CLI_VERSION_MAJOR}|g" \
          "cardano_node_cli_version_minor:''${CARDANO_CLI_VERSION_MINOR}|g" \
          "cardano_node_cli_version_patch:''${CARDANO_CLI_VERSION_PATCH}|g"

        statsd \
          "cardano_ping_latency_ms:''${CARDANO_PING_LATENCY}|g"
      '';
    };
    systemd.timers.custom-metrics = {
      timerConfig = {
        Unit = "custom-metrics.service";
        OnCalendar = "minutely";
      };
      wantedBy = [ "timers.target" ];
    };

    services.monitoring-exporters.extraPrometheusExporters = lib.optional (cfg.enableNetdata)
      {
        job_name = "netdata";
        scrape_interval = "60s";
        metrics_path = "/api/v1/allmetrics?format=prometheus";
        port = globals.netdataExporterPort;
      };
  };
}
