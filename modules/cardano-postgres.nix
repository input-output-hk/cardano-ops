pkgs: { config, ... }:
with pkgs;

let
  inherit (lib) mkForce mkIf mkEnableOption mkOption types;
  cfg = config.services.cardano-postgres;
in {
  options = {
    services.cardano-postgres = {
      enable = mkEnableOption "Cardano Postgres";
      postgresqlSocketPath = mkOption {
        description = "The postgresql socket path to use, typically `/run/postgresql`.";
        type = types.str;
        default = "/run/postgresql";
      };
      postgresqlDataDir = mkOption {
        description = "The directory for postgresql data.  If null, this parameter is not configured.";
        type = types.nullOr types.str;
        default = null;
      };
    };
  };
  config = mkIf cfg.enable {
    services.postgresql = {
      enable = true;
      package = postgresql_12;
      dataDir = mkIf (cfg.postgresqlDataDir != null) cfg.postgresqlDataDir;
      enableTCPIP = false;
      extraConfig = if globals.withHighCapacityExplorer then ''
        # Optimized for:
        # DB Version: 12
        # OS Type: linux
        # DB Type: web
        # Total Memory (RAM): 16 GB (half the RAM of high capacity explorer)
        # CPUs num: 8 (high capacity explorer vCPUs)
        # Connections num: 200
        # Data Storage: ssd
        # Suggested optimization for
        # other configurations can be
        # found at:
        # https://pgtune.leopard.in.ua/
        max_connections = 200
        shared_buffers = 4GB
        effective_cache_size = 12GB
        maintenance_work_mem = 1GB
        checkpoint_completion_target = 0.7
        wal_buffers = 16MB
        default_statistics_target = 100
        random_page_cost = 1.1
        effective_io_concurrency = 200
        work_mem = 5242kB
        min_wal_size = 1GB
        max_wal_size = 4GB
        max_worker_processes = 8
        max_parallel_workers_per_gather = 4
        max_parallel_workers = 8
        max_parallel_maintenance_workers = 4
      '' else ''
        # DB Version: 12
        # OS Type: linux
        # DB Type: web
        # Total Memory (RAM): 8 GB (half the RAM of regular explorer)
        # CPUs num: 4 (explorer vCPUs)
        # Connections num: 200
        # Data Storage: ssd
        max_connections = 200
        shared_buffers = 2GB
        effective_cache_size = 6GB
        maintenance_work_mem = 512MB
        checkpoint_completion_target = 0.7
        wal_buffers = 16MB
        default_statistics_target = 100
        random_page_cost = 1.1
        effective_io_concurrency = 200
        work_mem = 5242kB
        min_wal_size = 1GB
        max_wal_size = 4GB
        max_worker_processes = 4
        max_parallel_workers_per_gather = 2
        max_parallel_workers = 4
        max_parallel_maintenance_workers = 2
      '';
    };
  };
}
