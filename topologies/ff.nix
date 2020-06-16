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
  nbRelaysPerRegion = 3;

  nbRelay = relayNodesRegions * nbRelaysPerRegion;

  regions = {
    a = "eu-central-1";
    b = "ap-northeast-1";
    c = "ap-southeast-1";
    d = "us-east-2";
    e = "us-west-1";
    f = "sa-east-1";
  };
  regionLetters = (attrNames regions);

  indexedRegions = imap0 (rIndex: rLetter:
    { inherit rIndex rLetter;
      region = getAttr rLetter regions; }
  ) regionLetters;

  relayIndexesInRegion = genList (i: i + 1) nbRelaysPerRegion;

  ffProducers = lib.imap0 (index: cp: cp // { inherit index; })
    (globals.static.additionalPeers ++ import ./ff-peers.nix);

  relayNodesBaseDef = concatMap (nodeIndex:
    map ({rLetter, rIndex, region}:
      let
        name = "e-${rLetter}-${toString nodeIndex}";
        globalRelayIndex = rIndex + (nodeIndex - 1) * relayNodesRegions;
      in {
        inherit region name;
        producers =
          # One of the core node:
          [ "c-${elemAt regionLetters (mod rIndex coreNodesRegions)}-${toString (mod (nodeIndex - 1) nbCoreNodesPerRegion + 1)}" ]
          # all relay in same region:
          ++ map (i: "e-${rLetter}-${toString i}") (filter (i: i != nodeIndex) relayIndexesInRegion)
          # all relay with same suffix in other regions:
          ++ map (r: "e-${r}-${toString nodeIndex}") (filter (r: r != rLetter) regionLetters)
          # a share of the community relays:
          ++ (filter (p: mod p.index (nbRelay) == globalRelayIndex) ffProducers);
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

  "${globals.faucetHostname}" = withDailyRestart {
    services.cardano-faucet = {
      anonymousAccess = true;
      faucetLogLevel = "DEBUG";
      secondsBetweenRequestsAnonymous = 86400;
      secondsBetweenRequestsApiKeyAuth = 86400;
      lovelacesToGiveAnonymous = 100000000000;
      lovelacesToGiveApiKeyAuth = 1000000000000;
    };
  };

  explorer = withDailyRestart {};

  coreNodes = [
    # backup OBFT centralized nodes
    {
      name = "c-a-1";
      region = "eu-central-1";
      producers = [ "c-b-1" "c-c-1" "c-a-2" "e-a-1" "e-d-1" ];
      org = "IOHK";
      nodeId = 1;
    }
    {
      name = "c-b-1";
      region = "ap-northeast-1";
      producers = [ "c-c-1" "c-a-1" "c-b-2" "e-b-1" "e-e-1" ];
      org = "IOHK";
      nodeId = 2;
    }
    {
      name = "c-c-1";
      region = "ap-southeast-1";
      producers = [ "c-a-1" "c-b-1" "c-c-2" "e-c-1" "e-f-1" ];
      org = "IOHK";
      nodeId = 3;
    }
    # stake pools
    {
      name = "c-a-2";
      region = "eu-central-1";
      producers = [ "c-b-2" "c-c-2" "c-a-1" "e-a-2" "e-e-2" ];
      org = "IOHK";
      nodeId = 4;
    }
    {
      name = "c-b-2";
      region = "ap-northeast-1";
      producers = [ "c-c-2" "c-a-2" "c-b-1" "e-b-2" "e-f-2" ];
      org = "IOHK";
      nodeId = 5;
    }
    {
      name = "c-c-2";
      region = "ap-southeast-1";
      producers = [ "c-a-2" "c-b-2" "c-c-1" "e-c-2" "e-d-2" ];
      org = "IOHK";
      nodeId = 6;
    }
  ];

  relayNodes = map withDailyRestart relayNodesBaseDef;
}
