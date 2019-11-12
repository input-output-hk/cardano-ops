{ targetEnv
, tiny, medium
, ...
}:
with (import ../nix {});
let

  inherit (lib) recursiveUpdate mapAttrs listToAttrs imap0;
  inherit (pkgs) copyPathToStore;
  inherit (iohk-ops-lib) roles modules;

  # for now, keys need to be generated for each core nodes with:
  # for i in {1..2}; do cardano-cli --byron-legacy keygen --secret ./keys/$i.sk --no-password; done
  coreNodes = [
    {
      name = "a1";
      region = "eu-central-1";
      zone = "eu-central-1b";
      staticRoutes = [["b1"] ["r1"] ["c1"]];
    }
    {
      name = "b1";
      region = "eu-west-1";
      zone = "eu-west-1a";
      staticRoutes = [["c1"] ["r2"] ["a1"]];
    }
    {
      name = "c1";
      region = "ap-southeast-1";
      zone = "ap-southeast-1b";
      staticRoutes = [["a1"] ["r3"] ["b1"]];
    }
    #{
    #  name = "d1";
    #  region = "eu-central-1";
    #  zone = "eu-central-1b";
    #  staticRoutes = [["a1" "b1"] ["c1"]];
    #}
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

  cardanoNodes = listToAttrs (imap0 mkCoreNode coreNodes)
    // listToAttrs (map mkRelayNode relayNodes);

  otherNodes = {
    monitoring = {
      deployment.ec2.region = "eu-central-1";
      imports = [ medium roles.monitor ];
    };
  };

  nodes = mapAttrs (_: mkNode) (cardanoNodes // otherNodes);

  mkSigningKey = i: copyPathToStore (../configuration/delegate-keys.00 + "${toString i}.key");
  mkDelegationCertificate = i: copyPathToStore (../configuration/delegation-cert.00 + "${toString i}.json");

  mkCoreNode = i: def: {
    inherit (def) name;
    value = {
      deployment.ec2.region = def.region;
      deployment.ec2.zone = def.zone;
      imports = [ tiny ../roles/core.nix ];
      services.cardano-node.nodeId = i;
      services.cardano-node.genesisFile = ../configuration/genesis.json;
      services.cardano-node.genesisHash = lib.fileContents ../configuration/GENHASH;
      services.cardano-node.signingKey = toString (mkSigningKey i);
      services.cardano-node.delegationCertificate = toString (mkDelegationCertificate i);
    };
  };

  mkRelayNode = def: {
    inherit (def) name;
    value = {
      deployment.ec2.region = def.region;
      deployment.ec2.zone = def.zone;
      imports = [ tiny ../roles/core.nix ];
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
