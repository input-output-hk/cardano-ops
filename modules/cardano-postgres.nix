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
      extraConfig = ''
        # Optimized for:
        # DB Version: 12
        # OS Type: linux
        # DB Type: web
        # Total Memory (RAM): 16 GB
        # Data Storage: ssd
        # Suggested optimization for
        # other configurations can be
        # found at:
        # https://pgtune.leopard.in.ua/
        max_connections = 200
        shared_buffers = 2GB
        effective_cache_size = 6GB
        maintenance_work_mem = 512MB
        checkpoint_completion_target = 0.7
        wal_buffers = 16MB
        default_statistics_target = 100
        random_page_cost = 1.1
        effective_io_concurrency = 200
        work_mem = 10485kB
        min_wal_size = 1GB
        max_wal_size = 2GB
      '';
    };
  };
}
