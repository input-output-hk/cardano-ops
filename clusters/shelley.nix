{ targetEnv
, tiny, medium
, ...
}:
with (import ../nix {});
let

  inherit (lib) recursiveUpdate mapAttrs listToAttrs imap1;
  inherit (iohk-ops-lib) roles modules;

  # for now, keys need to be generated for each core nodes with:
  # for i in {1..2}; do cardano-cli --byron-legacy keygen --secret ./keys/$i.sk --no-password; done
  coreNodes = [
    {
      name = "a1";
      region = "eu-central-1";
      zone = "eu-central-1b";
      staticRoutes = [["b1" "c1"] ["r1"] ["d1"]];
    }
    {
      name = "b1";
      region = "eu-west-1";
      zone = "eu-west-1a";
      staticRoutes = [["c1" "d1"] ["r2"] ["a1"]];
    }
    {
      name = "c1";
      region = "ap-southeast-1";
      zone = "ap-southeast-1b";
      staticRoutes = [["d1" "a1"] ["r3"] ["b1"]];
    }
    {
      name = "d1";
      region = "eu-central-1";
      zone = "eu-central-1b";
      staticRoutes = [["a1" "b1"] ["c1"]];
    }
  ];

  relayNodes = [
    {
      name = "r1";
      region = "ap-southeast-1";
      zone = "ap-southeast-1b";
      static-routes = [["a1"] ["b1"]];
    }
    {
      name = "r2";
      region = "eu-central-1";
      zone = "eu-central-1b";
      static-routes = [["b1"] ["c1"]];
    }
    {
      name = "r3";
      region = "eu-central-1";
      zone = "eu-central-1b";
      static-routes = [["c1"] ["d1"]];
    }
  ];

  cardanoNodes = listToAttrs (imap1 mkCoreNode coreNodes)
    // listToAttrs (map mkRelayNode relayNodes);

  otherNodes = {
    monitoring = {
      deployment.ec2.region = "eu-central-1";
      imports = [ medium roles.monitor ];
    };
  };

  nodes = mapAttrs (_: mkNode) (cardanoNodes // otherNodes);

  mkCoreNode = i: def: {
    inherit (def) name;
    value = {
      deployment.ec2.region = def.region;
      deployment.ec2.zone = def.zone;
      imports = [ tiny ../roles/core.nix ];
      services.cardano-node.nodeId = i;
      # imports = [ tiny (import ../roles/legacy-core.nix i) ];
      # services.cardano-node-legacy.staticRoutes = def.staticRoutes;
    };
  };

  mkRelayNode = def: {
    inherit (def) name;
    value = {
      deployment.ec2.region = def.region;
      deployment.ec2.zone = def.zone;
      imports = [ tiny ../roles/core.nix ];
      # imports = [ tiny ../roles/legacy-relay.nix ];
      # services.cardano-node-legacy.staticRoutes = def.staticRoutes;
    };
  };

  mkNode = args:
    recursiveUpdate {
      deployment.targetEnv = targetEnv;
      nixpkgs.overlays = import ../overlays sources;
    } args;

in {
  network.description = "shelley-cluster";
  network.enableRollback = true;
} // nodes
