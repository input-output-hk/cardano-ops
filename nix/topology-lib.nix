pkgs: with pkgs; with lib; {
  mkRelayTopology = {
    regions
  , coreNodes
    # Since we don't have relays in every regions,
    # we define a substitute region for each region we don't deploy to;
  , regionsSubstitutesExtra ? {}
  , regionsSubstitutes ? {
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
    } // regionsSubstitutesExtra
  }:
    let

      inUseRegions = mapAttrsToList (_: r: r.name) regions;
      regionLetters = (attrNames regions);
      indexedRegions = imap0 (rIndex: rLetter:
        { inherit rIndex rLetter;
          region = regions.${rLetter}.name; }
      ) regionLetters;

      thirdPartyRelays = globals.static.additionalPeers ++
        (filter (r: !(hasSuffix globals.relaysNew r.addr))
          (if builtins.pathExists ../static/registered_relays_topology.json then
            (builtins.fromJSON (builtins.readFile ../static/registered_relays_topology.json)).Producers
          else []));

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

      indexedCoreNodes = imap0 (index: mergeAttrs {inherit index;}) coreNodes;

      nbRelaysPerRegions = mapAttrs (_: {minRelays, name, ...}:
        # we scale so that relays have less than 20 producers, with a given minimum:
        max minRelays (2 + (builtins.div (length (thirdPartyRelaysByRegions.${name} or [])) 20))
      ) regions;
    in
      imap1 (i: r:
        removeAttrs r ["nodeIndex"] // { nodeId = i + (length coreNodes); }
      ) (sort (r1: r2: r1.nodeIndex < r2.nodeIndex) (concatMap ({rLetter, rIndex, region}:
        let
          nbRelays = nbRelaysPerRegions.${rLetter};
          relayIndexesInRegion = genList (i: i + 1) nbRelays;
        in map (nodeIndex:
          let
            name = "rel-${rLetter}-${toString nodeIndex}";
          in {
            inherit region name nodeIndex;
            producers =
              # a share of the core nodes:
              (map (c: c.name) (filter (c: mod c.index nbRelays == (nodeIndex - 1)) indexedCoreNodes))
              # all relay in same region:
              ++ map (i: "rel-${rLetter}-${toString i}") (filter (i: i != nodeIndex) relayIndexesInRegion)
              # one relay in each other regions:
              ++ map (r: "rel-${r}-${toString (mod (nodeIndex - 1) nbRelaysPerRegions.${r} + 1)}") (filter (r: r != rLetter) regionLetters)
              # a share of the third-party relays:
              ++ (filter (p: mod p.index nbRelays == (nodeIndex - 1)) (indexedThirdPartyRelays.${region} or []));
            org = "IOHK";
          }
        ) relayIndexesInRegion
      ) indexedRegions));

}
