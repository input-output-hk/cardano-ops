{ config, lib, ... }:
with import ../nix {};

let
  inherit (lib) mkForce mkIf mkEnableOption mkOption types;
  cardano-sl-pkgs = import sourcePaths.cardano-sl { gitrev = sourcePaths.cardano-sl.rev; };
  explorerPythonAPI = cardano-sl-pkgs.explorerPythonAPI;
  cfg = config.services.explorer-python-api;
in {
  options = {
    services.explorer-python-api = {
      enable = mkEnableOption "Explorer Python API";
      epochSlots = mkOption {
        description = "The number of slots per epoch. 0 < EPOCHSLOTS <= 21600";
        type = types.ints.positive;
        default = 21600;
      };
      addrMaxLen = mkOption {
        description = "The maximum address length: 200 <= ADDRMAXLEN <= 8000";
        type = types.ints.positive;
        default = 200;
      };
      legacyProxyPort = mkOption {
        description = "The legacy explorer port to proxy to; typically 8100 or 8101.";
        type = types.ints.positive;
        default = 8101;
      };
      pythonApiProxyPort = mkOption {
        description = "The python explorer API port to proxy to; typically 7000.";
        type = types.ints.positive;
        default = 7000;
      };
      pythonApiMetricsPort = mkOption {
        description = "The python explorer API prometheus metrics port; typically 7001.";
        type = types.ints.positive;
        default = 7001;
      };
    };
  };
  config = mkIf cfg.enable {
    services.nginx = mkIf config.services.nginx.enable {
      virtualHosts = {
        "${globals.explorerHostName}.${globals.domain}" = mkForce {
          locations = if (globals.initialPythonExplorerDBSyncDone) then {
            # Pass to python API once the initial DB dump sync has completed
            "/api/addresses/summary/".proxyPass = "http://127.0.0.1:${toString cfg.pythonApiProxyPort}";
          } else {
            # Otherwise use the main explorer API
            "/api/addresses/summary/".proxyPass = "http://127.0.0.1:${toString cfg.legacyProxyPort}";
          };
        };
        "explorer-ip" = {
          locations = {
            "/metrics/explorer-python-api" = {
              proxyPass = "http://127.0.0.1:${toString cfg.pythonApiMetricsPort}/";
            };
          };
        };
      };
    };
    networking.firewall.allowedTCPPorts = [ cfg.pythonApiProxyPort cfg.pythonApiMetricsPort ];
    users.users.explorer-python-api = {
      home = "/var/empty";
      isSystemUser = true;
    };
    systemd.services.explorer-python-api = {
      wantedBy = [ "multi-user.target" ];
      environment = {
        DBSOCKPATH = config.services.cardano-postgres.postgresqlSocketPath;
        prometheus_multiproc_dir = "/tmp/explorer-python-metrics";
        ADDRMAXLEN = builtins.toString cfg.addrMaxLen;
        EXPLORERURL = "http://localhost:${toString cfg.legacyProxyPort}";
      };
      preStart = "sleep 5";
      script = "exec ${explorerPythonAPI}/bin/run-explorer-python-api";
      serviceConfig = {
        User = "explorer-python-api";
        Restart = "always";
        RestartSec = "30s";
      };
    };
    systemd.services.explorer-python-dumper = {
      wantedBy = [ "multi-user.target" ];
      environment = {
        DBSOCKPATH = config.services.cardano-postgres.postgresqlSocketPath;
        EPOCHSLOTS = "${builtins.toString cfg.epochSlots}";
        ADDRMAXLEN = "${builtins.toString cfg.addrMaxLen}";
        EXPLORERURL = "http://localhost:${toString cfg.legacyProxyPort}";
      };
      preStart = "sleep 5";
      script = "exec ${explorerPythonAPI}/bin/run-explorer-python-dumper";
      serviceConfig = {
        User = "explorer-python-api";
        Restart = "always";
        RestartSec = "30s";
      };
    };
    services.cardano-postgres.enable = true;
    services.postgresql = {
      initialScript = pkgs.writeText "explorerPythonAPI-initScript" ''
        create database explorer_python_api;
        \connect explorer_python_api;
        create schema scraper;
        create table scraper.blocks (
                                cbeBlkHash        text      primary key
                              , cbeEpoch          smallint
                              , cbeSlot           smallint
                              , cbeBlkHeight      integer
                              , cbeTimeIssued     timestamp without time zone
                              , cbeTxNum          integer
                              , cbeTotalSent      bigint
                              , cbeSize           integer
                              , cbeBlockLead      text
                              , cbeFees           bigint
                              , cbsPrevHash       text
                              , cbsNextHash       text
                              , cbsMerkleRoot     text
                              );
        create index i_blocks_cbeBlkHash on scraper.blocks (cbeBlkHash asc);
        create table scraper.tx (
                                ctsId               text      primary key
                              , ctsTxTimeIssued     timestamp without time zone
                              , ctsBlockTimeIssued  timestamp without time zone
                              , ctsBlockHash        text
                              , ctsTotalInput       bigint
                              , ctsTotalOutput      bigint
                              , ctsFees             bigint
                              );
        create index i_tx_ctsId on scraper.tx (ctsId asc);
        create index i_tx_ctsTxTimeIssued on scraper.tx (ctsTxTimeIssued asc);
        create table scraper.txinput (
                                ctsId               text
                              , ctsIdIndex          smallint
                              , ctsTxTimeIssued     timestamp without time zone
                              , ctsInputAddr        text
                              , ctsInput            bigint
                              , constraint pk_txinput primary key (ctsId, ctsIdIndex)
                              );
        create index i_txinput_ctsId on scraper.txinput (ctsId asc);
        create index i_txinput_ctsIdIndex on scraper.txinput (ctsIdIndex asc);
        create index i_txinput_ctsTxTimeIssued on scraper.txinput (ctsTxTimeIssued asc);
        create index i_txinput_ctsInputAddr_ctsId on scraper.txinput (ctsInputAddr asc, ctsId asc);
        create table scraper.txoutput (
                                ctsId               text
                              , ctsIdIndex          smallint
                              , ctsTxTimeIssued     timestamp without time zone
                              , ctsOutputAddr       text
                              , ctsOutput           bigint
                              , constraint pk_txoutput primary key (ctsId, ctsIdIndex)
                              );
        create index i_txoutput_ctsId on scraper.txoutput (ctsId asc);
        create index i_txoutput_ctsIdIndex on scraper.txoutput (ctsIdIndex asc);
        create index i_txoutput_ctsTxTimeIssued on scraper.txoutput (ctsTxTimeIssued asc);
        create index i_txoutput_ctsOutputAddr_ctsId on scraper.txoutput (ctsOutputAddr asc, ctsId asc);
        create user explorer_python_api;
        grant all privileges on database explorer_python_api to explorer_python_api;
        grant all privileges on schema scraper to explorer_python_api;
        grant all privileges on all tables in schema scraper to explorer_python_api;
      '';
      identMap = ''
        explorer-users explorer-python-api explorer_python_api
        explorer-users root explorer_python_api
        explorer-users postgres postgres
        explorer-users cexplorer cexplorer
        explorer-users root cexplorer
      '';
      authentication = ''
        local all all ident map=explorer-users
      '';
    };
  };
}
