pkgs: with pkgs; with lib; rec {

  inherit (globals.topology) regions;


  /* Used when connecting to thrid-party relays by regions affinitiy,
    since we don't have relays in every regions,
    we define a substitute region for each region we don't deploy to; */
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
    # For when we use only 3 regions:
    eu-west-2 = "eu-central-1";
    us-west-1 = "us-east-2";
    ap-northeast-1 = "ap-southeast-1";
  } // (globals.topology.regionsSubstitutes or {});

  /* function composition */
  compose = f: g: x: f (g x);

  /* compose list of function */
  composeAll = builtins.foldl' compose id;

  /* Round a float to integer, toward 0. */
  roundToInt = f: toInt (head (splitString "." (toString f)));

  withModule = m: def: def // {
    imports = (def.imports  or []) ++ [m];
  };

  /* Auto restart cardano-node service every given hours
    (plus 'nodeId' minutes to reduce likelyhood of simultaneous restart of many nodes).
  */
  withAutoRestartEvery = h: def: withModule {
    services.cardano-node.extraServiceConfig = i: {
      serviceConfig.RuntimeMaxSec = h *
        60 * 60 + 60 * ((def.nodeId or 0) + (5 * i));
    };
  } def;

  /* Modify node definition for some nodes that statisfy predicate.
  */
  forNodesWith = p: modDef: def: if (p def)
    then (lib.recursiveUpdate def modDef) // (optionalAttrs (modDef ? imports) {
      imports = (def.imports  or []) ++ modDef.imports;
    })
    else def;

  /* Modify node definition for some given nodes, by name.
  */
  forNodes = modDef: nodes: forNodesWith (def: elem def.name nodes) modDef;

  /* Enable the given profiling mode (first arg) for
    the given list of nodes (second arg).
  */
  withProfiling = p: (forNodes {
    services.cardano-node = {
      profiling = p;
      extraServiceConfig = _: {
        serviceConfig = {
          # Disable autorestart (which would override profiling data):
          RuntimeMaxSec = "infinity";
          Restart = "no";
        };
      };
    };
  });

  /* Enable eventlog collection for the given list of nodes (first arg).
  */
  withEventlog = nodes: def: lib.recursiveUpdate {
    services.cardano-node.eventlog = true;
  } def;

  /* return the dns name of the continental group of relay
     that is the nearest to the given region.
  */
  relayGroupForRegion = region:
      let prefix =
        if (hasPrefix "ap" region) then "asia-pacific"
        else if (hasPrefix "us" region) then "north-america"
        else "europe";
      in "${prefix}.${globals.relaysNew}";

  /* return the dns name of the continental group of relay, for the target env,
     that is the nearest to the given region.
  */
  envRelayGroupForRegion = region:
    let prefix =
        if (hasPrefix "ap" region) then "asia-pacific"
        else if (hasPrefix "us" region) then "north-america"
        else "europe";
      in "${prefix}.${globals.environmentConfig.relaysNew}";

  /* Connect a group of nodes (second arg) with the given group (first arg),
     so that every nodes of the first group appears exactly once
     among all the producers arrays of the nodes in the second group.
  */
  connectGroupWith = withGroup: let
    withGroupSize = length withGroup;
    indexedWithGroup = imap0 (idx: node: { inherit idx node;}) withGroup;
  in group: let
    groupSize = length group;
    interval = groupSize / withGroupSize;
    indexedGroup = imap0 (idx: node: { inherit idx node;}) group;
    withGroupProducers = if (groupSize <= withGroupSize)
    then idx: filter (n: mod n.idx groupSize == idx) indexedWithGroup
    else idx: optional (mod idx interval == 0 && idx / interval < withGroupSize)
      (elemAt indexedWithGroup (idx / interval));
  in
    map ({idx, node}: node // {
      producers = node.producers ++ map (n: n.node.name) (withGroupProducers idx);
    }) indexedGroup;

  /* Same as 'connectGroupWith' but with regional affinity:
     nodes only connect to nodes in the same region.
  */
  regionalConnectGroupWith = withGroup: let
    withGroupByRegion = mapAttrs (_: connectGroupWith) (groupBy (n: n.region) withGroup);
    in group: let
      byRegion = groupBy (n: n.region) group;
      byName = groupBy (n: n.name)
        (concatLists (mapAttrsToList (r: (withGroupByRegion.${r} or id)) byRegion));
    in map (node: node // {
      producers = (head byName.${node.name}).producers;
    }) group;

  /* given a node group size, this function return the minimal number of peers required so
     that every node in the group is connected within one "hop" to every other nodes in that group.
  */
  nbPeersOneHopGroup =
    let
      # list of max number of nodes that can be connected within one hop using 'nbPeers':
      maxNbNodes = genList (nbPeers: { maxNbNodes = nbPeers * nbPeers + nbPeers; inherit nbPeers;}) 100;
    in groupSize: (findFirst (i: groupSize <= i.maxNbNodes) (throw "too many nodes") maxNbNodes).nbPeers;

  /* given a node group size, this function return the minimal number of peers required so
     that every node in the group is connected within two "hops" to every other nodes in that group.
  */
  nbPeersTwoHopsGroup =
    let
      # list of max number of nodes that can be connected within two hop using 'nbPeers':
      maxNbNodes = genList (nbPeers: { maxNbNodes = nbPeers * nbPeers * nbPeers + nbPeers * nbPeers + nbPeers; inherit nbPeers;}) 100;
    in groupSize: (findFirst (i: groupSize <= i.maxNbNodes) (throw "too many nodes") maxNbNodes).nbPeers;

  /* given a constraint in maximum number of peers and a node group size,
     this function return the minimal number of peers required so that every node in the group
     is connected within one hop (if possible within 'maxPeers') or two hops (otherwise)
     to every other nodes in that group.
  */
  nbPeersWithin = maxPeers: groupSize: let
    nbPeers1Hop = nbPeersOneHopGroup groupSize;
    in if (groupSize <= (maxPeers + 1)) then groupSize - 1
      else if (nbPeers1Hop <= maxPeers) then nbPeers1Hop
      else nbPeersTwoHopsGroup groupSize;

  /* return the given node group so that it form a fully connected network
  */
  fullyConnectNodes = nodeGroup:
    connectNodesWithin (length nodeGroup) nodeGroup;

  /* return the given node group so that it form a network connected via one hop at max.
  */
  oneHopConnectNodes = nodeGroup:
    connectNodesWithin (nbPeersOneHopGroup (length  nodeGroup)) nodeGroup;

  /* return the given node group so that it form a network connected via two hops at max.
  */
  twoHopsConnectNodes = nodeGroup:
    connectNodesWithin (nbPeersTwoHopsGroup (length  nodeGroup)) nodeGroup;

  /* given a constraint in maximum number of peers, this function connect the given node group
     so that every node in the group is connected within one hop (if possible within 'maxPeers')
     or two hops (otherwise) to every other nodes in that group.
  */
  connectNodesWithin = maxPeers: nodeGroup: let
    groupSize = length nodeGroup;
    nbPeers = nbPeersWithin maxPeers groupSize;
    indexedNodes = imap0 (idx: node: { inherit idx node;}) nodeGroup;
    names = let names = map (n: n.name) nodeGroup; in names ++ names; # to avoid overflows
    topologies = map ({node, idx}:
      rec { inherit node;
          # the producers are taken from the nodeGroup (excluding it-self), in order, by chucks of 'nbPeers' peers,
          # for this we keep track of the chuck location ('endIndexExcluded') used by each node, so that the next one can start
          # from the end of the previous node chuck of peers.
          startIndex = if idx == 0 then 1 else mod ((elemAt topologies (idx - 1)).endIndexExcluded) groupSize;
          endIndexExcluded = let unfiltrerProducers = sublist startIndex nbPeers names;
            in startIndex + nbPeers + (if (elem node.name unfiltrerProducers) then 1 else 0);
          producers = filter (p: p != node.name) (sublist startIndex (endIndexExcluded - startIndex) names);
      }
    ) indexedNodes;
    in map (n: n.node // {
      producers = filter (p: !(elem p (n.node.producers or []))) n.producers
         ++ (n.node.producers or []);
    }) topologies;

  /* return registered tird-party relays, as saved in static/registered_relays_topology.json from
     https://${globals.explorerHostName}/relays/topology.json
  */
  thirdPartyRelays = globals.static.additionalPeers ++
    (filter (r: !(hasSuffix globals.relaysNew r.addr))
      (if builtins.pathExists ../static/registered_relays_topology.json then
        (builtins.fromJSON (builtins.readFile ../static/registered_relays_topology.json)).Producers
      else []));

  /* return the relays regional dns entry that is closest to the given region,
     as a producer with given valency.
     For use by core nodes to avoid relying on specific relay nodes,
     thus allowing restarting relays and scaling up/down easily without affecting core nodes.
  */
  regionalRelaysProducer = region: valency: {
    addr = relayGroupForRegion region;
    port = globals.cardanoNodePort;
    inherit valency;
  };

  /* return the target env relays regional dns entry that is closest to the given region,
     as a producer with given valency.
     For use by core nodes to avoid relying on specific relay nodes,
     thus allowing restarting relays and scaling up/down easily without affecting core nodes.
  */
  envRegionalRelaysProducer = region: valency: {
    addr = envRelayGroupForRegion region;
    port = globals.cardanoNodePort;
    inherit valency;
  };

  /* given regions (eg. { a = { name = "eu-central-1"; }; b = { name = "us-east-2"; };})
     return a function that return the basis of a bft core node definition,
     with name, region and relays as producers, from the region letter, an index (relative to region)
     and given additional attributes.
  */
  mkBftCoreNode = r: idx: attrs: rec {
    name = "bft-${r}-${toString idx}";
    stakePool = false;
    region = regions.${r}.name;
    producers = # some nearby relays:
      [ (envRegionalRelaysProducer region 2) ];
  } // attrs;

  /* given regions (eg. { a = { name = "eu-central-1"; }; b = { name = "us-east-2"; };})
     return a function that return the basis of a bft core node definition,
     with name, region and relays as producers, from the region letter, an index (relative to region)
     a ticker id and given additional attributes.
  */
  mkStakingPool = r: idx: ticker: attrs:
    let suffix = optionalString (ticker != "") "-${ticker}"; in rec {
    name = "stk-${r}-${toString idx}${suffix}";
    region = regions.${r}.name;
    producers =  # some nearby relays:
      [ (envRegionalRelaysProducer region 2) ];
    org = "IOHK";
    stakePool = true;
  } // (optionalAttrs (ticker != "") {
    inherit ticker;
  }) // attrs;

  /* Make a 3 nodes : 1 block producer, 2 relay, independent staking pool setup.
  */
  mkStakingPoolNodes = r1: id: r2: ticker: def: let
    stkNode = {
      name = "stk-${r1}-${toString id}-${ticker}";
      region = regions.${r1}.name;
      stakePool = true;
      inherit ticker;
      producers = [ relay1.name relay2.name ];
    } // def;
    relay1 = rec {
      name = "rel-${r1}-${toString id}";
      region = regions.${r1}.name;
      producers = [
        stkNode.name
        relay2.name
        (envRegionalRelaysProducer region 1)
      ];
    } // def;
    relay2 = rec {
      name = "rel-${r2}-${toString id}";
      region = regions.${r2}.name;
      producers = [
        stkNode.name
        relay1.name
        (envRegionalRelaysProducer region 1)
      ];
    } // def;
  in [
    stkNode
    relay1
    relay2
  ];

  stateAwsAffinityIndex = builtins.fromJSON (builtins.readFile (pkgs.aws-affinity-indexes + "/state-index.json"));

  thirdPartyRelaysByRegions = let regions' = mapAttrsToList (_: r: r.name) regions; in {
    # Regions were relays will be deployed (at least one if minRelays not defined), eg.:
    # ["eu-central-1" "us-east-2"];
    regions ? regions'
  }: let

    defaultRegion = head regions;

    allocateRegion = bestRegion: if (builtins.elem bestRegion regions) then bestRegion else allocateRegion (regionsSubstitutes.${bestRegion} or
          (builtins.trace "WARNING: relay affected to unknown 'region': ${bestRegion} (to be added in 'regionsSubstitutes'). Using ${defaultRegion})" defaultRegion));

    thirdPartyRelaysByRegions = groupBy (r: r.region) (map
      (relay:
        let bestRegion = stateAwsAffinityIndex.${relay.state} or
          (builtins.trace "WARNING: relay has unknow 'state': ${relay.state}. Using ${defaultRegion})" defaultRegion);
        in relay // {
          region = converge allocateRegion bestRegion;
        }
      ) thirdPartyRelays);

  in mapAttrs (_: (imap0 (index: mergeAttrs {inherit index;}))) thirdPartyRelaysByRegions;

  connectWithThirdPartyRelays = relays:
  let
    byRegion = groupBy (n: n.region) relays;
    regions = attrNames byRegion;
    indexedThirdPartyRelays = thirdPartyRelaysByRegions { inherit regions; };
  in
    concatMap (region:
      let
        indexed = imap0 (idx: node: { inherit idx node;}) byRegion.${region};
        nbRelays = length indexed;
      in map (n: n.node // {
        producers = (n.node.producers or []) ++
          (filter (p: mod p.index nbRelays == n.idx) (indexedThirdPartyRelays.${region} or []));
      }) indexed
    ) regions;

  /* Generate relay nodes definitions,
     potentially with auto-scaling so that relay nodes can support all third-party block producers.
     Third-party producers are allocated to relays in the nearest provided region (using https://github.com/turnkeylinux/aws-datacenters).
  */
  mkRelayTopology = let regions' = regions; in {
    # Regions were relays will be deployed (at least one if minRelays not defined), eg.:
    # { a = { name = "eu-central-1"; minRelays = 3; };
    #   b = { name = "us-east-2"; minRelays = 2; }; }
    regions ? regions'
   # core nodes to be included in producers arrays of relays
   # each core node appears exactly once accross relays of each region:
  , coreNodes
  # relays are named using a ${relayPrefix}-${regionLetter}-${index} scheme:
  , relayPrefix ? "rel"
  # each relay as a maximum of 'maxInRegionPeers' other relays of same region in producers array.
  # Reducing this parameter increase room for third-party relays.
  , maxInRegionPeers ? 6
  # Limit producers array size to 'maxProducersPerNode' on average (plus or minus 1 depending on nodes).
  # Increasing this parameter gives room for more third-party relays, at the expense of (linearly) more CPU/ram comsumption.
  , maxProducersPerNode ? 20
  # if true (default) the number of relays in each will computed so that it can handle all third party relays while
  # staying below 'maxProducersPerNode' constraint (but in all case above "minRelays" defined for region).
  , autoscaling ? true
  }:
    let

      inUseRegions = mapAttrsToList (_: r: r.name) regions;
      nbRegions = length inUseRegions;
      nbCoreNodes = length coreNodes;
      regionLetters = attrNames regions;
      indexedRegions = imap0 (rIndex: rLetter:
        { inherit rIndex rLetter;
          region = regions.${rLetter}.name; }
      ) regionLetters;

      indexedThirdPartyRelays = thirdPartyRelaysByRegions { regions = inUseRegions; };

      nbRelaysPerRegions = mapAttrs (_: {minRelays ? 1, name, ...}:
        # we scale so that relays have less than `maxRelaysPerNode` producer relays per node, with a given minimum of relays:
        let
          nbThirdPartyRelays = length (indexedThirdPartyRelays.${name} or []);
          intraInstancesProducers = nbPeersWithin maxInRegionPeers globals.nbInstancesPerRelay;
          nbProducersToShare = nbCoreNodes + nbThirdPartyRelays + (nbRegions - 1);
          autoScale = nbRelaysInput:
            # producer slots available, excluding local region peers:
            let availableProducersSlots = globals.nbInstancesPerRelay * (maxProducersPerNode - intraInstancesProducers)
              - (nbPeersWithin maxInRegionPeers nbRelaysInput);
            nbRelays = nbProducersToShare / availableProducersSlots + # round up the division:
              (if (mod nbProducersToShare availableProducersSlots == 0) then 0 else 1);
            in max nbRelaysInput nbRelays; # 'max' is used to ensure convergence (this can oversize a bit, but also allows some growth without re-scaling)
          nbRelaysAutoScale = converge autoScale 1;
        in
          if (!autoscaling) then
            builtins.trace (if (minRelays < nbRelaysAutoScale) then  "Warning: only ${toString minRelays} relays in ${name} but ${toString nbRelaysAutoScale} would be necessary to handle the ${toString nbThirdPartyRelays} third-party relays."
              else "Using given ${toString minRelays} min relays for ${name} (autoscaling would use ${toString nbRelaysAutoScale} to handle the ${toString nbThirdPartyRelays} third-party relays).")
            minRelays
          else builtins.trace (if (minRelays > nbRelaysAutoScale) then "Using given ${toString minRelays} min relays for ${name} (autoscaling would use ${toString nbRelaysAutoScale} to handle the ${toString nbThirdPartyRelays} third-party relays)."
            else "Autoscaling for region ${name}: using ${toString nbRelaysAutoScale} relays to handle the ${toString nbThirdPartyRelays} third-party relays.")
            (max minRelays nbRelaysAutoScale)
      ) regions;
    in
      imap1 (i: r:
        removeAttrs r ["nodeIndex"] // { nodeId = i + (length coreNodes); }
      ) (sort (r1: r2: r1.nodeIndex < r2.nodeIndex) (concatMap ({rLetter, rIndex, region}:
        let
          nbRelays = nbRelaysPerRegions.${rLetter};
          relayIndexesInRegion = genList (i: i + 1) nbRelays;
          relaysForRegion = map (nodeIndex:
            let
              name = "${relayPrefix}-${rLetter}-${toString nodeIndex}";
            in {
              inherit region name nodeIndex;
              producers = # one relay in each other regions, using a scale factor to spread accross all relays of other regions:
                map (r: let scaleFactor = (nbRelaysPerRegions.${r} + 0.0) / nbRelays; in
                 "${relayPrefix}-${r}-${toString (roundToInt ((nodeIndex - 1) * scaleFactor) + 1)}")
                  (filter (r: r != rLetter) regionLetters)
                # a share of the third-party relays:
                ++ (filter (p: mod p.index nbRelays == (nodeIndex - 1)) (indexedThirdPartyRelays.${region} or []));
              org = "IOHK";
              services.cardano-node.maxIntraInstancesPeers = maxInRegionPeers;
            }
          ) relayIndexesInRegion;
          # coreNodes shift in a way that accomplish full rotation accross regions:
          coreNodesShift = rIndex * nbCoreNodes / nbRegions;
        in
          # Ensure every core nodes appears in the producer array of one relay in each region,
          # the shift is there to improve connectivity with core nodes
          # (eg. so that rel-a-1 and rel-b-1 don't both connect to the same core node)
          connectGroupWith (shiftList coreNodesShift coreNodes)
          # Ensure every relay inside the region is as connected as possible within `maxInRegionPeers`:
         (connectNodesWithin maxInRegionPeers relaysForRegion)
      ) indexedRegions));

  readAvailabilityZones = nixops-export-json:
    let
      inherit (lib.head (lib.attrValues (builtins.fromJSON (builtins.readFile nixops-export-json))))
        resources;
      nodes = filterAttrs (_: v: v ? "ec2.zone") resources;
    in mapAttrs (n: v: v."ec2.zone") nodes;


  withAvailabilityZone = overrides: nodes: let
    byRegions = groupBy (n: n.region) nodes;
    withZones = mapAttrs (region: imap0 (idx: node:
      node // {
        zone = node.zone or overrides.${node.name} or (
          let zones = subtractLists globals.disabledAvailabilityZones aws-regions.${region}.zones;
          in elemAt zones (lib.mod idx (lib.length zones)));
      }
    )) byRegions;
    byName = groupBy (n: n.name) (concatLists (attrValues withZones));
  in
    map (n: head byName.${n.name}) nodes;

  /* Generate n batches (if possible) of relay nodes, as a list of lists of node names,
     in a way that minimize impact on connectivity within each regions.
  */
  genRelayBatches = n: let
    byRegions = attrValues (mapAttrs (_: regionRelays:
      let indexed = imap0 (i: mergeAttrs {inherit i;}) regionRelays;
      # within each regions, create n lists using mod result, so that each batches does not includes consecutive relays (eg. rel-a-1 and rel-a-2),
      # which could deteriorate connectivity within each region:
      in genList (i: (map (r: r.name) (filter (r: mod r.i n == i) indexed))) n)
    (groupBy (r: r.region) globals.topology.relayNodes));
    # then join each list in same position in each region, to form final batches
    # (also exclude empty batches, which can happen if n > #relays for each region)
    in filter (b: b != []) (genList (i: concatMap (rs: elemAt rs i) byRegions) n);

  /* Compute the minimum number of batches necessary to stay below
     a given maximum number of nodes per batches.
  */
  nbBatches = let
    regionSizes = mapAttrsToList (_: length) (groupBy (r: r.region) globals.topology.relayNodes);
    batchSizes = genList (n: rec {
        size = foldl (s: rs: s + (rs / nbBatches) + (if (mod rs nbBatches == 0) then 0 else 1)) 0 regionSizes;
        nbBatches = n + 1;}) 100;
    in maxBatchSize: (findFirst (i: i.size <= maxBatchSize)
      (throw "max batch size cannot be under number of regions") batchSizes).nbBatches;
}
