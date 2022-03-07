pkgs: { name, config, nodes, resources, ... }:
with pkgs;
let
  faucetPkgs = (import (sourcePaths.cardano-faucet + "/nix") {});
  walletPackages = import sourcePaths.cardano-wallet { gitrev = sourcePaths.cardano-wallet.rev; };
  inherit (walletPackages) cardano-wallet;
  cardanoNodePkgs = getCardanoNodePackages private.project.hsPkgs.cardano-node.src;
  inherit (pkgs.lib) mkIf;
in {

  imports = [
    cardano-ops.modules.base-service

    # Cardano faucet needs to pair a compatible version of wallet with node
    # The following service import will do this:
    (sourcePaths.cardano-faucet + "/nix/nixos/cardano-faucet-service.nix")
  ];

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  environment.systemPackages = with pkgs; [
    sqlite-interactive
  ];

  services.cardano-faucet = {
    enable = true;
    cardanoEnv = globals.environmentName;
    cardanoEnvAttrs = globals.environmentConfig;
    walletPackage = cardano-wallet;
  };

  services.cardano-node = {
    inherit cardanoNodePkgs;
    allProducers = if (globals.topology.relayNodes != [])
        then [ globals.relaysNew ]
        else (map (n: n.name) globals.topology.coreNodes);
    topology = lib.mkForce null;
    totalMaxHeapSizeMbytes = 0.6 * config.node.memory * 1024;
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

    "faucet.recaptcha" = {
      keyFile = ../static + "/faucet.recaptcha";
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
  users.users.cardano-node.extraGroups = [ "keys" ];

  security.acme = mkIf (config.deployment.targetEnv != "libvirtd") {
    email = "devops@iohk.io";
    acceptTerms = true; # https://letsencrypt.org/repository/
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
        https://testnets.cardano.org 1;
        https://developers.cardano.org 1;
        https://staging-testnets-cardano.netlify.app 1;
        http://localhost:8000 1;
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
