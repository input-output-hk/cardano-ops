pkgs: with pkgs; with lib;
let
  withDailyRestart = def: lib.recursiveUpdate {
    systemd.services.cardano-node.serviceConfig = {
      RuntimeMaxSec = 6 * 60 * 60 + 60 * (5 * (def.nodeId or 0));
    };
  } def;

  coreNodesRegions = 3;
  relayNodesRegions = 6;

  nbCoreNodesPerRegion = 2;
  nbRelaysPerRegion = 1;

  nbRelay = relayNodesRegions * nbRelaysPerRegion;

  regions = {
    a = "eu-central-1";
    b = "ap-northeast-1";
    c = "ap-southeast-1";
    d = "us-east-2";
    e = "us-west-1";
    f = "eu-west-1";
  };
  regionLetters = (attrNames regions);

  indexedRegions = imap0 (rIndex: rLetter:
    { inherit rIndex rLetter;
      region = getAttr rLetter regions; }
  ) regionLetters;

  relayIndexesInRegion = genList (i: i + 1) nbRelaysPerRegion;

  peerProducers = lib.imap0 (index: cp: cp // { inherit index; })
    (globals.static.additionalPeers ++ (builtins.tail (builtins.fromJSON (builtins.readFile ../static/registered_relays_topology.json)).Producers));

  relayNodesBaseDef = concatMap (nodeIndex:
    map ({rLetter, rIndex, region}:
      let
        name = "rel-${rLetter}-${toString nodeIndex}";
        globalRelayIndex = rIndex + (nodeIndex - 1) * relayNodesRegions;
      in {
        inherit region name;
        producers =
          # One of the core node:
          [ "bft-${elemAt regionLetters (mod rIndex coreNodesRegions)}-${toString (mod (nodeIndex - 1) nbCoreNodesPerRegion + 1)}" ]
          # all relay in same region:
          ++ map (i: "rel-${rLetter}-${toString i}") (filter (i: i != nodeIndex) relayIndexesInRegion)
          # all relay with same suffix in other regions:
          ++ map (r: "rel-${r}-${toString nodeIndex}") (filter (r: r != rLetter) regionLetters)
          # a share of the community relays:
          ++ (filter (p: mod p.index (nbRelay) == globalRelayIndex) peerProducers);
        org = "IOHK";
        nodeId =  8 + globalRelayIndex;
      }
    ) (take relayNodesRegions indexedRegions)
  ) relayIndexesInRegion;

in {
  legacyCoreNodes = [];

  legacyRelayNodes = [];

  byronProxies = [];

  monitoring = {
    services.monitoring-services.publicGrafana = true;
  };

  "${globals.faucetHostname}" = {
    services.cardano-faucet = {
      anonymousAccess = true;
      faucetLogLevel = "DEBUG";
      secondsBetweenRequestsAnonymous = 86400;
      secondsBetweenRequestsApiKeyAuth = 86400;
      lovelacesToGiveAnonymous = 1000000000;
      lovelacesToGiveApiKeyAuth = 1000000000000;
      faucetFrontendUrl = "";
      useByronWallet = true;
    };
  };

  explorer = withDailyRestart {
    services.nginx.virtualHosts."${globals.explorerHostName}.${globals.domain}".locations."/p" = {
      root = ../modules/iohk-pools/mainnet_candidate;
    };
  };

  coreNodes = [
    # backup OBFT centralized nodes
    {
      name = "bft-a-1";
      region = "eu-central-1";
      producers = [ "bft-b-1" "bft-c-1" "stk-a-1-IOHK1" "rel-a-1" "rel-d-1" ];
      org = "IOHK";
      nodeId = 1;
    }
    {
      name = "bft-b-1";
      region = "ap-northeast-1";
      producers = [ "bft-c-1" "bft-a-1" "stk-b-1-IOHK2" "rel-b-1" "rel-e-1" ];
      org = "IOHK";
      nodeId = 2;
    }
    {
      name = "bft-c-1";
      region = "ap-southeast-1";
      producers = [ "bft-a-1" "bft-b-1" "stk-c-1-IOHK3" "rel-c-1" "rel-f-1" ];
      org = "IOHK";
      nodeId = 3;
    }
    # stake pools
    {
      name = "stk-a-1-IOHK1";
      region = "eu-central-1";
      producers = [ "stk-b-1-IOHK2" "stk-c-1-IOHK3" "bft-a-1" "rel-a-2" "rel-e-2" ];
      org = "IOHK";
      nodeId = 4;
    }
    {
      name = "stk-b-1-IOHK2";
      region = "ap-northeast-1";
      producers = [ "stk-c-1-IOHK3" "stk-a-1-IOHK1" "bft-b-1" "rel-b-2" "rel-f-2" ];
      org = "IOHK";
      nodeId = 5;
    }
    {
      name = "stk-c-1-IOHK3";
      region = "ap-southeast-1";
      producers = [ "stk-a-1-IOHK1" "stk-b-1-IOHK2" "bft-c-1" "rel-c-2" "rel-d-2" ];
      org = "IOHK";
      nodeId = 6;
    }
  ];

  relayNodes = map withDailyRestart relayNodesBaseDef;
}
