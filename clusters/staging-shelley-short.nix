{ targetEnv
, tiny, medium, large
, ...
}:
let
  inherit (import ../nix {}) iohk-ops-lib lib sourcePaths;
  inherit (lib) recursiveUpdate mapAttrs listToAttrs imap1;
  inherit (iohk-ops-lib) roles modules;

  # for now, keys need to be generated for each core nodes with:
  # for i in {1..2}; do cardano-cli --byron-legacy keygen --secret ./keys/$i.sk --no-password; done
  coreNodes = [
    {
      name = "c-a-1";
      region = "eu-central-1";
      staticRoutes = [
        [ "c-a-2" "c-a-3" ]
        [ "c-b-1" "c-b-2" ]
        [ "r-a-1" "r-a-2" ]
      ];
      org = "IOHK";
    }
    {
      name = "c-a-2";
      region = "eu-central-1";
      staticRoutes = [
        [ "c-a-3" "c-a-1" ]
        [ "c-c-2" "c-c-1" ]
        [ "r-a-2" "r-a-3" ]
      ];
      org = "IOHK";
    }
    {
      name = "c-a-3";
      region = "eu-central-1";
      staticRoutes = [
        [ "c-a-1" "c-a-2" ]
        [ "r-a-3" "r-a-1" ]
        [ "r-b-1" "r-c-1" ]
      ];
      org = "IOHK";
    }
    {
      name = "c-b-1";
      region = "ap-northeast-1";
      staticRoutes = [
        [ "c-b-2" "r-b-2" ]
        [ "c-c-1" "c-c-2" ]
        [ "r-b-1" "r-b-2" ]
      ];
      org = "Emurgo";
    }
    {
      name = "c-b-2";
      region = "ap-northeast-1";
      staticRoutes = [
        [ "c-a-2" "c-a-1" ]
        [ "c-b-1" "r-b-1" ]
        [ "r-b-2" "r-b-1" ]
      ];
      org = "Emurgo";
    }
    {
      name = "c-c-1";
      region = "ap-southeast-1";
      staticRoutes = [
        [ "c-a-1" "c-a-2" ]
        [ "c-c-2" "r-c-1" ]
        [ "r-c-1" "r-c-2" ]
      ];
      org = "CF";
    }
    {
      name = "c-c-2";
      region = "ap-southeast-1";
      staticRoutes = [
        [ "c-b-2" "c-b-1" ]
        [ "c-c-1" "r-c-1" ]
        [ "r-c-2" "r-c-1" ]
      ];
      org = "CF";
    }
  ];

  relayNodes = [
    {
      name = "r-a-1";
      region = "eu-central-1";
      staticRoutes = [
        [ "c-a-1" "c-a-3" ]
        [ "c-a-2" "c-a-3" ]
        [ "r-a-2" "r-a-3" ]
        [ "r-b-1" "r-b-2" ]
      ];
      org = "IOHK";
    }
    {
      name = "r-a-2";
      region = "eu-central-1";
      staticRoutes = [
        [ "c-a-1" "c-a-2" ]
        [ "c-a-3" "c-a-2" ]
        [ "r-a-3" "r-a-1" ]
        [ "r-c-1" "r-c-2" ]
      ];
      org = "IOHK";
    }
    {
      name = "r-a-3";
      region = "eu-central-1";
      staticRoutes = [
        [ "c-a-2" "c-a-1" ]
        [ "c-a-3" "c-a-1" ]
        [ "r-a-1" "r-a-2" ]
      ];
      org = "IOHK";
    }
    {
      name = "r-b-1";
      region = "ap-northeast-1";
      staticRoutes = [
        [ "c-b-1" "c-b-2" ]
        [ "r-a-1" "r-a-3" ]
        [ "r-b-2" "r-a-2" ]
      ];
      org = "IOHK";
    }
    {
      name = "r-b-2";
      region = "ap-northeast-1";
      staticRoutes = [
        [ "c-b-2" "c-b-1" ]
        [ "r-b-1" "r-a-2" ]
        [ "r-c-1" "r-c-2" ]
      ];
      org = "IOHK";
    }
    {
      name = "r-c-1";
      region = "ap-southeast-1";
      staticRoutes = [
        [ "c-c-1" "c-c-2" ]
        [ "r-a-3" "r-a-2" ]
        [ "r-c-2" "r-a-2" ]
      ];
      org = "IOHK";
    }
    {
      name = "r-c-2";
      region = "ap-southeast-1";
      staticRoutes = [
        [ "c-c-2" "c-c-1" ]
        [ "r-b-2" "r-b-1" ]
        [ "r-c-1" "r-a-2" ]
      ];
      org = "IOHK";
    }
  ];


  cardanoNodes = listToAttrs (imap1 mkCoreNode coreNodes)
    // listToAttrs (map mkRelayNode relayNodes);

  otherNodes = {
    monitoring = {
      deployment.ec2.region = "eu-central-1";
      imports = [
        medium
        roles.monitor
      ];
      node.isMonitoring = true;
    };
  };

  nodes = mapAttrs (_: mkNode) (cardanoNodes // otherNodes);

  mkCoreNode = i: def: {
    inherit (def) name;
    value = {
      deployment.ec2.region = def.region;
      imports = [ large ../roles/legacy-core.nix ];
      services.cardano-node-legacy.staticRoutes = def.staticRoutes;
      node.isCardanoLegacyCore = true;
      node2.coreIndex = i;
      node2.org = def.org;
    };
  };

  mkRelayNode = def: {
    inherit (def) name;
    value = {
      deployment.ec2.region = def.region;
      imports = [ large ../roles/legacy-relay.nix ];
      services.cardano-node-legacy.staticRoutes = def.staticRoutes;
      node.isCardanoLegacyRelay = true;
      node2.org = def.org;
    };
  };

  mkNode = args:
    recursiveUpdate {
      deployment.targetEnv = targetEnv;
      nixpkgs.overlays = import ../overlays sourcePaths;
    } args;

in {
  network.description = "shelley-cluster";
  network.enableRollback = true;
} // nodes
