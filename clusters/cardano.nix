{ targetEnv
, tiny
, medium
, large
, ...
}:
with (import ../nix {});
let

  inherit (globals) topology byronProxyPort;
  inherit (topology) legacyCoreNodes legacyRelayNodes byronProxies coreNodes relayNodes;
  inherit (lib) recursiveUpdate mapAttrs listToAttrs imap1;
  inherit (iohk-ops-lib) roles modules;

  # for now, keys need to be generated for each core nodes with:
  # for i in {1..2}; do cardano-cli --byron-legacy keygen --secret ./keys/$i.sk --no-password; done

  cardanoNodes = listToAttrs (imap1 mkLegacyCoreNode legacyCoreNodes)
    // listToAttrs (map mkLegacyRelayNode legacyRelayNodes)
    // listToAttrs (map mkCoreNode coreNodes)
    // listToAttrs (map mkRelayNode relayNodes);

  otherNodes = {
    monitoring = {
      deployment.ec2.region = "eu-central-1";
      imports = [
        large
        roles.monitor
      ];
      node = {
        roles.isMonitor = true;
        org = "IOHK";
      };
    };
  };

  nodes = mapAttrs (_: mkNode) (cardanoNodes // otherNodes);

  mkSigningKey = i: copyPathToStore (../configuration/delegate-keys.00 + "${toString i}.key");
  mkDelegationCertificate = i: copyPathToStore (../configuration/delegation-cert.00 + "${toString i}.json");

  mkCoreNode = i: def: {
    inherit (def) name;
    value = {
      node = {
        roles.isCardanoCore = true;
        inherit (def) org;
      };
      deployment.ec2.region = def.region;
      imports = [ large ../roles/core.nix ];
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
      node = {
        roles.isCardanoRelay = true;
        inherit (def) org;
      };
      deployment.ec2.region = def.region;
      imports = [ large ../roles/relay.nix ];
    };
  };

  mkExplorerNode = def: {
    inherit (def) name;
    value = {
      deployment.ec2.region = def.region;
      imports = [ medium ../roles/explorer.nix ];
    };
  };

  mkLegacyCoreNode = i: def: {
    inherit (def) name;
    value = {
      node = {
        roles.isCardanoLegacyCore = true;
        coreIndex = i;
        inherit (def) org;
      };
      deployment.ec2.region = def.region;
      imports = [ large ../roles/legacy-core.nix ];
      services.cardano-node-legacy.staticRoutes = def.staticRoutes;
    };
  };

  mkLegacyRelayNode = def: {
    inherit (def) name;
    value = {
      node = {
        roles.isCardanoLegacyRelay = true;
        inherit (def) org;
      };
      deployment.ec2.region = def.region;
      imports = [ large ../roles/legacy-relay.nix ];
      services.cardano-node-legacy.staticRoutes = def.staticRoutes or [];
      services.cardano-node-legacy.dynamicSubscribe = def.dynamicSubscribe or [];
    };
  };

  mkNode = args:
    recursiveUpdate {
      deployment.targetEnv = targetEnv;
      nixpkgs.overlays = import ../overlays sourcePaths;
    } args;

in {
  network.description = "Cardano cluster - ${globals.deploymentName}";
  network.enableRollback = true;
} // nodes
