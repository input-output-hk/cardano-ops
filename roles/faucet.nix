pkgs: { name, config, nodes, resources, ... }:
with pkgs;
let
  faucetPkgs = (import (sourcePaths.cardano-faucet + "/nix") {}).pkgs;
  hostAddr = getListenIp nodes.${name};
  nodePort = globals.cardanoNodePort;
  monitoringPort = globals.cardanoNodePrometheusExporterPort;
in {

  imports = [
    cardano-ops.modules.common

    # Cardano faucet needs to pair a compatible version of wallet with node
    # The following service import will do this:
    (sourcePaths.cardano-faucet + "/nix/nixos/cardano-faucet-service-with-node.nix")

    # To instead use this deployments own native cardano node niv pin,
    # switch to the following two imports.  This may break the faucet wallet!
    # A compatible wallet package may be specified with the cardano-faucet
    # walletPackage option.
    #(sourcePaths.cardano-faucet + "/nix/nixos/cardano-faucet-service.nix")
    #(sourcePaths.cardano-node + "/nix/nixos")
  ];

  environment.systemPackages = with pkgs; [
    faucetPkgs.cardano-wallet-byron
    jq
  ];

  networking.firewall.allowedTCPPorts = [
    80
    443
    nodePort
    monitoringPort
  ];

  services.monitoring-exporters.extraPrometheusExportersPorts = [ monitoringPort ];

  services.cardano-faucet = {
    enable = true;
    cardanoEnv = globals.environmentName;

    # Defaults to 1000 ADA per request
    #lovelacesToGive = 1000000000;

    # Defaults to INFO
    #faucetLogLevel = "DEBUG";

    # Defaults to a 1 day rate request limit, exemptable by API key
    #secondsBetweenRequests = 3600;
  };

  deployment.keys = {
    "faucet.mnemonic" = {
      keyFile = ../static + "/faucet.mnemonic";
      destDir = "/var/lib/keys/";
      user = "cardano-node";
      permissions = "0400";
    };

    "faucet.passphrase" = {
      keyFile = ../static + "/faucet.passphrase";
      destDir = "/var/lib/keys/";
      user = "cardano-node";
      permissions = "0400";
    };

    "faucet.apikey" = {
      keyFile = ../static + "/faucet.apikey";
      destDir = "/var/lib/keys/";
      user = "cardano-node";
      permissions = "0400";
    };
  };

  # NOTE: Cardano Faucet maintains its own cardano-node niv pin which is used here
  users.users.cardano-node.extraGroups = [ "keys" ];
  services.cardano-node.nodeConfig = globals.environmentConfig.nodeConfig // {
    hasPrometheus = [ hostAddr monitoringPort ];
  };

  services.nginx = {
    enable = true;
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;
    recommendedProxySettings = true;
    serverTokens = false;
    mapHashBucketSize = 128;

    commonHttpConfig = ''
      log_format x-fwd '$remote_addr - $remote_user [$time_local] '
                        '"$request" $status $body_bytes_sent '
                        '"$http_referer" "$http_user_agent" "$http_x_forwarded_for"';
      access_log syslog:server=unix:/dev/log x-fwd;
      limit_req_zone $binary_remote_addr zone=faucetPerIP:100m rate=1r/s;
      limit_req_status 429;
      server_names_hash_bucket_size 128;

      map $http_origin $origin_allowed {
        default 0;
        https://testnet.iohkdev.io 1;
        https://testnets.cardano.org 1;
        https://staging-testnets-cardano.netlify.com 1;
        https://staging-testnets-cardano.netlify.app 1;
      }

      map $origin_allowed $origin {
        default "";
        1 $http_origin;
      }
    '';

    virtualHosts = {
      "${name}.${globals.domain}" = {
        forceSSL = config.deployment.targetEnv != "libvirtd";
        enableACME = config.deployment.targetEnv != "libvirtd";

        locations."/" = {
          extraConfig = let
            headers = ''
              add_header 'Vary' 'Origin' always;
              add_header 'Access-Control-Allow-Origin' $origin always;
              add_header 'Access-Control-Allow-Methods' 'POST, OPTIONS' always;
              add_header 'Access-Control-Allow-Headers' 'User-Agent,X-Requested-With,Content-Type' always;
            '';
          in ''
            limit_req zone=faucetPerIP;

            if ($request_method = OPTIONS) {
              ${headers}
              add_header 'Access-Control-Max-Age' 1728000;
              add_header 'Content-Type' 'text/plain; charset=utf-8';
              add_header 'Content-Length' 0;
              return 204;
              break;
            }

            if ($request_method = POST) {
              ${headers}
            }

            proxy_pass http://127.0.0.1:${
              toString config.services.cardano-faucet.faucetListenPort
            };
            proxy_set_header Host $host:$server_port;
            proxy_set_header X-Real-IP $remote_addr;
          '';
        };
      };
    };
  };
}
