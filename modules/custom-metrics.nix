pkgs: { config, options, name, nodes, resources, ... }:
let
  lib = pkgs.lib;
  cfg = config.services.custom-metrics;
  cfgExporters = config.services.monitoring-exporters;
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
        default = 42;
        description = "The testnet magic number";
      };

      useTestnetMagic = mkOption {
        type = types.bool;
        default = true;
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
      path = with pkgs; [ cardano-cli coreutils gnugrep gnused jq nmap procps ];
      environment = {
        CARDANO_NODE_SOCKET_PATH = "/run/cardano-node/node.socket";
      };
      script = ''
        STATSD_HOST="localhost"
        STATSD_PORT="${if (cfg.statsdExporter == "node") then (toString cfgExporters.statsdPort) else (toString cfg.netdataStatsdPort)}"

        MAGIC="${if cfg.useTestnetMagic then "--testnet-magic ${toString cfg.testnetMagicNumber}" else ""}"
        OPCERT="${cfg.opcertFile}"

        # Default decoded metric settings in case they are not obtainable
        KES_CREATED_PERIOD="0"

        # Default genesis metric settings in case they are not obtainable
        ACTIVE_SLOTS_COEFF="0"
        EPOCH_LENGTH="0"
        MAX_KES_EVOLUTIONS="0"
        SECURITY_PARAM="0"
        SLOTS_PER_KES_PERIOD="0"
        SLOT_LENGTH="0"

        # Default protocol metric settings in case they are not obtainable
        A_0="0"
        DECENTRALISATION_PARAM="0"
        E_MAX="0"
        KEY_DECAY_RATE="0"
        KEY_DEPOSIT="0"
        KEY_MIN_REFUND="0"
        MAX_BLOCK_BODY_SIZE="0"
        MAX_BLOCK_HEADER_SIZE="0"
        MAX_TX_SIZE="0"
        MIN_FEE_A="0"
        MIN_FEE_B="0"
        MIN_UTXO_VALUE="0"
        N_OPT="0"
        POOL_DECAY_RATE="0"
        POOL_DEPOSIT="0"
        POOL_MIN_REFUND="0"
        PROTOCOL_VERSION_MINOR="0"
        PROTOCOL_VERSION_MAJOR="0"
        RHO="0"
        TAU="0"

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

        # main
        #
        if [ -f "$OPCERT" ]; then
          echo "Cardano node opcert file is: $OPCERT"
          KES_CREATED_PERIOD=$(cardano-cli shelley text-view decode-cbor --file $OPCERT | sed '8q;d'  | cut -d '(' -f2 | cut -d ')' -f1)
        fi

        if CONFIG=$(pgrep -a cardano-node | grep -oP ".*--config \K.*\.json"); then
          echo "Cardano node config file is: $CONFIG"
          if GENESIS=$(jq -r '.GenesisFile' < "$CONFIG"); then
            echo "Cardano node genesis file is: $GENESIS"
            if [ -f "$GENESIS" ]; then
              ACTIVE_SLOTS_COEFF=$(jq '.activeSlotsCoeff' < "$GENESIS")
              EPOCH_LENGTH=$(jq '.epochLength' < "$GENESIS")
              SLOTS_PER_KES_PERIOD=$(jq '.slotsPerKESPeriod' < "$GENESIS")
              SLOT_LENGTH=$(jq '.slotLength' < "$GENESIS")
              MAX_KES_EVOLUTIONS=$(jq '.maxKESEvolutions' < "$GENESIS")
              SECURITY_PARAM=$(jq '.securityParam' < "$GENESIS")
            fi
          fi
        fi

        if PROTOCOL_CONFIG=$(cardano-cli shelley query protocol-parameters $MAGIC); then
          A_0=$(jq '.a0' <<< "$PROTOCOL_CONFIG")
          DECENTRALISATION_PARAM=$(jq '.decentralisationParam' <<< "$PROTOCOL_CONFIG")
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

        statsd \
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
      '';
    };
    systemd.timers.custom-metrics = {
      timerConfig = {
        Unit = "custom-metrics.service";
        OnCalendar = "minutely";
      };
      wantedBy = [ "timers.target" ];
    };
  };
}
