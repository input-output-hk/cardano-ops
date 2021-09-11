pkgs: { config, nodes, ... }:
with pkgs;
let backendAddr = let
  suffix = {
    ec2 = "-ip";
    libvirtd = "";
    packet = "";
  }.${config.deployment.targetEnv};
  in name: if (globals.explorerBackendsInContainers)
    then "${name}.containers"
    else "explorer-${name}${suffix}";
in {

  imports = [
    (cardano-ops.roles.explorer globals.explorerDbSnapshots)
  ];

  # Disable services not necessary for snapshots:
  services.cardano-ogmios.enable = lib.mkForce false;
  services.graphql-engine.enable = lib.mkForce false;
  services.cardano-graphql.enable = lib.mkForce false;
  services.cardano-rosetta-server.enable = lib.mkForce false;
  services.cardano-submit-api.enable = lib.mkForce false;
  services.nginx.enable = lib.mkForce false;

  # Create a new snapshot every 24h (if not exist alreay):
  services.cardano-db-sync.takeSnapshot = "always";
  systemd.services.cardano-db-sync.serviceConfig.RuntimeMaxSec = 24 * 60 * 60;

  environment.systemPackages = with pkgs; [
    bat fd lsof netcat ncdu ripgrep tree vim dnsutils
  ];

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  services.traefik = {
    enable = true;
    staticConfigOptions = {
      metrics.prometheus = {
        entryPoint = "metrics";
      };
      entryPoints = {
        web = {
          address = ":80";
          http = {
            redirections = {
              entryPoint = {
                to = "websecure";
                scheme = "https";
              };
            };
          };
        };
        websecure = {
          address = ":443";
        };
        metrics = {
          address = ":${toString globals.cardanoExplorerGwPrometheusExporterPort}";
        };
      };
      certificatesResolvers.default.acme = {
        email = "devops@iohk.io";
        storage = "/var/lib/traefik/acme.json";
        httpChallenge = {
          entryPoint = "web";
        };
      };
    };
    dynamicConfigOptions = {
      http = {
        routers = {
          explorer = {
            rule = lib.concatStringsSep " || "
              (map (a: "Host(`${a}`)") ([globals.explorerHostName] ++ globals.explorerAliases));
            service = "explorer";
            tls.certResolver = "default";
          };
        };
        services = {
          explorer = {
            loadBalancer = {
              servers = map (b: {
                url = "http://${backendAddr b}";
              }) globals.explorerActiveBackends;
            };
          };
        };
      };
    };
  };

  services.monitoring-exporters.extraPrometheusExporters = [
    {
      job_name = "explorer-gateway-exporter";
      scrape_interval = "10s";
      metrics_path = "/metrics";
      port = globals.cardanoExplorerGwPrometheusExporterPort;
    }
  ];

  services.dnsmasq.enable = true;

  networking.nat = {
    enable = globals.explorerBackendsInContainers;
    internalInterfaces = [ "ve-+" ];
    externalInterface = "ens5";
  };
  networking.firewall.trustedInterfaces = config.networking.nat.internalInterfaces;

  containers = lib.optionalAttrs globals.explorerBackendsInContainers (let
    indexes = lib.listToAttrs (lib.imap1 (lib.flip lib.nameValuePair) (lib.attrNames globals.explorerBackends));
  in
    lib.mapAttrs (z: variant: let
      hostAddress = "192.168.100.${toString indexes.${z}}0";
      localAddress = "192.168.100.${toString indexes.${z}}1";
    in {
      privateNetwork = true;
      autoStart = true;
      inherit hostAddress localAddress;
      config = {
        _module.args = {
          name = "explorer-${z}";
          nodes = nodes // {
            "explorer-${z}" = {
              config.networking.privateIPv4 = localAddress;
              options.networking.privateIPv4.isDefined = true;
              options.networking.publicIPv4.isDefined = false;
            };
          };
          resources = {};
        };
        nixpkgs.pkgs = pkgs;
        imports = [(cardano-ops.roles.explorer variant)];
        networking.nameservers = [ hostAddress ];
        node = {
          inherit (config.node) nodeId;
          memory = config.node.memory / (lib.length (lib.attrNames globals.explorerBackends));
        };
      };
    }) globals.explorerBackends
  );
}
