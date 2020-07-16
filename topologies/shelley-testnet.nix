pkgs: with pkgs; with lib;
let
  withDailyRestart = def: lib.recursiveUpdate {
    systemd.services.cardano-node.serviceConfig = {
      RuntimeMaxSec = (if (def.name == "rel-a-1") then 72 else 6) *
        60 * 60 + 60 * (5 * (def.nodeId or 0));
    };
  } def;

  bftCoreNodes = filter (n: hasPrefix "bft-" n.name) coreNodes;
  nbBftCoreNodes = length bftCoreNodes;
  stakingPoolNodes = filter (n: hasPrefix "stk-" n.name) coreNodes;
  nbStakingPoolNodes = length stakingPoolNodes;

  regions = mapAttrs (_: {name, minRelays}: {
    inherit name;
    # we scale so that relays have less than 20 producers, with a given minimum:
    nbRelays = max minRelays ((max nbBftCoreNodes nbStakingPoolNodes)
      + (builtins.div (length thirdPartyRelaysByRegions.${name}) 20));
  }) {
    a = { name = "eu-central-1";   # Europe (Frankfurt);
      minRelays = 5;
    };
    b = { name = "us-east-2";      # US East (Ohio)
      minRelays = 5;
    };
    c = { name = "ap-southeast-1"; # Asia Pacific (Singapore)
      minRelays = 5;
    };
    d = { name = "eu-west-2";      # Europe (London)
      minRelays = 5;
    };
    e = { name = "us-west-1";      # US West (N. California)
      minRelays = 5;
    };
    f = { name = "ap-northeast-1"; # Asia Pacific (Tokyo)
      minRelays = 5;
    };
  };

  inUseRegions = mapAttrsToList (_: r: r.name) regions;

  # Since we don't have relays in every regions,
  # we define a substitute region for each region we don't deploy to;
  regionsSubstitutes = {
    eu-north-1 = "eu-central-1";
    ap-northeast-3 = "ap-northeast-1";
    ap-northeast-2 = "ap-northeast-1";
    cn-north-1 = "ap-northeast-1";
    cn-northwest-1 = "ap-northeast-1";
    ap-east-1 = "ap-southeast-1";
    ap-south-1 = "ap-southeast-1";
    ap-southeast-2 = "ap-southeast-1";
    me-south-1 = "ap-southeast-1";
    us-east-1 = "us-east-2";
    sa-east-1 = "us-east-2";
    ca-central-1 = "us-east-2";
    us-west-2 = "us-west-1";
    af-south-1 = "eu-west-2";
    eu-west-1 = "eu-west-2";
    eu-west-3 = "eu-west-2";
  };

  regionLetters = (attrNames regions);

  indexedRegions = imap0 (rIndex: rLetter:
    { inherit rIndex rLetter;
      region = regions.${rLetter}.name; }
  ) regionLetters;

  thirdPartyRelays = globals.static.additionalPeers ++
    (filter (r: !(hasSuffix globals.relaysNew r.addr))
      (builtins.fromJSON (builtins.readFile ../static/registered_relays_topology.json)).Producers);

  stateAwsAffinityIndex = builtins.fromJSON (builtins.readFile (pkgs.aws-affinity-indexes + "/state-index.json"));

  thirdPartyRelaysByRegions = groupBy (r: r.region) (map
    (relay:
      let bestRegion = stateAwsAffinityIndex.${relay.state} or
        (builtins.trace "WARNING: relay has unknow 'state': ${relay.state}. Using ${regions.a.name})" regions.a.name);
      in relay // {
        region = if (builtins.elem bestRegion inUseRegions) then bestRegion else regionsSubstitutes.${bestRegion} or
        (builtins.trace "WARNING: relay affected to unknown 'region': ${bestRegion} (to be added in 'regionsSubstitutes'). Using ${regions.a.name})" regions.a.name);
      }
    ) thirdPartyRelays);

  indexedThirdPartyRelays = mapAttrs (_: (imap0 (index: mergeAttrs {inherit index;}))) thirdPartyRelaysByRegions;

  relayNodesBaseDef = imap1 (i:
    mergeAttrs { nodeId = i + (length coreNodes); }
   )(concatMap ({rLetter, rIndex, region}:
    let
      inherit (regions.${rLetter}) nbRelays;
      relayIndexesInRegion = genList (i: i + 1) nbRelays;
    in map (nodeIndex:
      let
        name = "rel-${rLetter}-${toString nodeIndex}";
      in {
        inherit region name;
        producers =
          # One of the bft code nodes and one of staking pool nodes:
          [ (elemAt bftCoreNodes (mod (nodeIndex - 1) nbBftCoreNodes)).name
            (elemAt stakingPoolNodes (mod (nodeIndex - 1) nbStakingPoolNodes)).name ]
          # all relay in same region:
          ++ map (i: "rel-${rLetter}-${toString i}") (filter (i: i != nodeIndex) relayIndexesInRegion)
          # one relay in each other regions:
          ++ map (r: "rel-${r}-${toString (mod (nodeIndex - 1) regions.${r}.nbRelays + 1)}") (filter (r: r != rLetter) regionLetters)
          # a share of the third-party relays:
          ++ (filter (p: mod p.index nbRelays == (nodeIndex - 1)) indexedThirdPartyRelays.${region});
        org = "IOHK";
      }
    ) relayIndexesInRegion
  ) indexedRegions);

  coreNodes = [
    # backup OBFT centralized nodes
    {
      name = "bft-a-1";
      region = regions.a.name;
      producers = [ "bft-b-1" "bft-c-1" "stk-a-1" "rel-a-1" "rel-d-1" ];
      org = "IOHK";
      nodeId = 1;
    }
    {
      name = "bft-b-1";
      region = regions.b.name;
      producers = [ "bft-a-1" "bft-c-1" "stk-b-1" "rel-b-1" "rel-c-1" ];
      org = "IOHK";
      nodeId = 2;
    }
    {
      name = "bft-c-1";
      region = regions.c.name;
      producers = [ "bft-a-1" "bft-b-1" "stk-c-1" "rel-c-1" "rel-f-1" ];
      org = "IOHK";
      nodeId = 3;
    }
    # stake pools
    {
      name = "stk-a-1";
      region = regions.a.name;
      producers = [ "stk-b-2" "stk-c-2" "bft-a-1" "rel-a-2" "rel-d-2" ];
      org = "IOHK";
      nodeId = 4;
    }
    {
      name = "stk-b-1";
      region = regions.b.name;
      producers = [ "stk-a-2" "stk-c-2" "bft-b-1" "rel-b-2" "rel-e-2" ];
      org = "IOHK";
      nodeId = 5;
    }
    {
      name = "stk-c-1";
      region = regions.c.name;
      producers = [ "stk-a-1" "stk-b-1" "bft-c-1" "rel-c-2" "rel-f-2" ];
      org = "IOHK";
      nodeId = 6;
    }
  ];

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
      faucetFrontendUrl = "https://testnets.cardano.org/en/shelley/tools/faucet/";
    };
  };

  explorer = withDailyRestart {
    services.nginx.virtualHosts."${globals.explorerHostName}.${globals.domain}".locations."/p" = {
      root = ../modules/iohk-pools/shelley_testnet;
    };
  };

  inherit coreNodes;

  relayNodes = map withDailyRestart relayNodesBaseDef;
}
