pkgs: with pkgs; with lib; with topology-lib;
let

  regions = {
    a = { name = "eu-central-1";   # Europe (Frankfurt);
    };
    b = { name = "us-east-2";      # US East (Ohio)
    };
    c = { name = "ap-southeast-1"; # Asia Pacific (Singapore)
    };
    d = { name = "eu-west-2";      # Europe (London)
    };
    e = { name = "us-west-1";      # US West (N. California)
    };
    f = { name = "ap-northeast-1"; # Asia Pacific (Tokyo)
    };
    g = { name = "sa-east-1";      # South America (São Paulo)
    };
  };

  nodes = with regions; map (composeAll [
    (recursiveUpdate {
      services.cardano-node = {
        useNewTopology = true;
        systemdSocketActivation = mkForce false;
        extraNodeConfig = {
          TraceBlockFetchClient = true;
          TraceChainSyncClient = true;
        };
      };
      node.roles.isPublicSsh = true;
      users.users.root.openssh.authorizedKeys.keys =
        iohk-ops-lib.ssh-keys.csl-developers.karknu;
    })
  ]) (concatLists [
    (mkStakingPoolNodes "a" 1 "d" "IOPP1" { org = "IOHK"; nodeId = 1; })
    (mkStakingPoolNodes "b" 2 "e" "IOPP2" { org = "IOHK"; nodeId = 2; })
    (mkStakingPoolNodes "c" 3 "f" "IOPP3" { org = "IOHK"; nodeId = 3; })
    (mkStakingPoolNodes "g" 4 "g" "IOPP4" { org = "IOHK"; nodeId = 4; })
  ]);

  relayNodes = filter (n: !(n ? stakePool)) nodes;

  coreNodes = filter (n: n ? stakePool) nodes;

in {

  inherit coreNodes relayNodes regions;

  monitoring = {
    services.monitoring-services.publicGrafana = false;
    services.nginx.virtualHosts."monitoring.${globals.domain}".locations."/p" = {
      root = ../static/pool-metadata;
    };
  };

}
