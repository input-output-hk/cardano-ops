with import ../nix { };
let
  inherit (pkgs.lib)
    attrValues attrNames filter filterAttrs flatten foldl' hasAttrByPath listToAttrs
    mapAttrs' mapAttrs nameValuePair recursiveUpdate unique optional any concatMap
    getAttrs optionalString hasPrefix take drop length concatStringsSep head toLower
    elem;

  inherit (globals.topology) coreNodes relayNodes;
  privateRelayNodes = globals.topology.privateRelayNodes or [ ];
  inherit (globals.ec2.credentials) accessKeyIds;
  inherit (iohk-ops-lib.physical) aws;

  cluster = import ../clusters/cardano.nix {
    inherit pkgs;
    inherit (globals.ec2) instances;
  };

  nodes = filterAttrs
    (name: node:
      ((node.deployment.targetEnv or null) == "ec2")
      && ((node.deployment.ec2.region or null) != null))
    cluster;

  nodeList = attrValues nodes;

  doMonitoring = any (n: n.node.roles.isMonitor or false) nodeList;

  regions =
    unique (map (node: node.deployment.ec2.region) nodeList);

  regionsByName = mapAttrs (_: head) (lib.groupBy (r: r.name) (attrValues globals.topology.regions));

  orgs =
    unique (map (node: node.node.org) nodeList);

  orgXregion = filter
    ({ org, region }: any
      (n:
        n.deployment.ec2.region == region
        && n.node.org == org)
      nodeList)
    (lib.cartesianProductOfSets {
      org = orgs;
      region = regions;
    });

  securityGroups = with aws.security-groups; [
    {
      nodes = getAttrs (map (n: n.name) (coreNodes ++ privateRelayNodes)) nodes;
      groups = [ (import ../physical/aws/security-groups/allow-peers.nix) ];
    }
    {
      nodes = getAttrs (map (n: n.name) relayNodes) nodes;
      groups = [ (import ../physical/aws/security-groups/allow-public.nix) ];
    }
    {
      nodes = filterAttrs (_: n: n.node.roles.isMonitor or false) nodes;
      groups = [
        allow-public-www-https
        allow-graylog
      ];
    }
    {
      nodes = (filterAttrs (_: n: n.node.roles.isExplorer or false) nodes);
      groups = [ allow-public-www-https ];
    }
    {
      nodes = (filterAttrs (_: n: n.node.roles.isExplorerBackend or false) nodes);
      groups = [ (import ../physical/aws/security-groups/allow-explorer-gw.nix) ];
    }
    {
      nodes = (filterAttrs (_: n: n.node.roles.isMetadata or false) nodes);
      groups = [ allow-public-www-https ];
    }
    {
      nodes = (filterAttrs (_: n: n.node.roles.isFaucet or false) nodes);
      groups = [ allow-public-www-https ];
    }
    {
      nodes = (filterAttrs (_: n: n.node.roles.isPublicSsh or false) nodes);
      groups = [ allow-ssh ];
    }
    {
      inherit nodes;
      groups = [ allow-deployer-ssh ]
        ++ optional doMonitoring
        allow-monitoring-collection;
    }
  ];

  importSecurityGroup = node: securityGroup:
    securityGroup {
      inherit pkgs lib nodes;
      region = node.deployment.ec2.region;
      org = node.node.org;
      vpcId = "vpc-${node.node.org}-${node.deployment.ec2.region}";
    };

  importSecurityGroups = { nodes, groups }:
    mapAttrs
      (_: n: foldl' recursiveUpdate { } (map (importSecurityGroup n) groups))
      nodes;

  securityGroupsByNode =
    foldl' recursiveUpdate { } (map importSecurityGroups securityGroups);

  settings = {
    resources = foldl' recursiveUpdate
      {
        ec2SecurityGroups =
          foldl' recursiveUpdate { } (attrValues securityGroupsByNode);

        elasticIPs = mapAttrs'
          (name: node:
            nameValuePair "${name}-ip" {
              accessKeyId = accessKeyIds.${node.node.org};
              inherit (node.deployment.ec2) region;
              vpc = true;
            })
          nodes;

        route53RecordSets = lib.optionalAttrs globals.withSmash
          {
            "smash-explorer-alias" = { resources, ... }: {
              zoneName = "${pkgs.globals.dnsZone}.";
              domainName = "smash.${globals.domain}.";
              recordValues = [ resources.machines.explorer ];
              recordType = "A";
              accessKeyId = pkgs.globals.ec2.credentials.accessKeyIds.dns;
            };
            "smash-explorer-alias-aaaa" = { resources, ... }: {
              zoneName = "${pkgs.globals.dnsZone}.";
              domainName = "smash.${globals.domain}.";
              recordValues = [ resources.machines.explorer ];
              recordType = "AAAA";
              accessKeyId = pkgs.globals.ec2.credentials.accessKeyIds.dns;
            };
          } // (lib.mapAttrs' (n: v: lib.nameValuePair "${n}-aaaa" (
            { resources, ... }: {
              zoneName = "${pkgs.globals.dnsZone}.";
              domainName = "${n}.${globals.domain}.";
              recordValues = [ resources.machines.${n} ];
              ipIndexes = lib.genList lib.id (lib.length resources.machines.${n}.deployment.ec2.ipv6AddressHostParts);
              recordType = "AAAA";
              accessKeyId = pkgs.globals.ec2.credentials.accessKeyIds.dns;
            }
          )) nodes) // (
          let mkRelayRecords = prefix:
            let
              relaysNewPrefix = "${prefix}${optionalString (prefix != "") "-"}relays-new";
            in
            relayFilter:
            let
              # AWS records are limited to 200 values:
              relays =
                let
                  filteredRelays = filter (r: (r.public or true) && relayFilter r) relayNodes;
                  numberOfRelays = length filteredRelays;
                in
                if (numberOfRelays > 200) then
                  builtins.trace
                    "WARNING: Getting over the 200 values limit for ${relaysNewPrefix} dns entry (${toString numberOfRelays} relays). Excluding ${concatStringsSep " " (map (r: r.name) (drop 200 filteredRelays))}."
                    (take 200 filteredRelays)
                else filteredRelays;
            in
            listToAttrs (lib.concatMap
              (relay: [
                (nameValuePair "${relaysNewPrefix}-${relay.name}" (
                  { resources, ... }: {
                    zoneName = "${pkgs.globals.dnsZone}.";
                    domainName = "${prefix}${optionalString (prefix != "") "."}${pkgs.globals.relaysNew}.";
                    recordValues = [ resources.machines.${relay.name} ];
                    recordType = "A";
                    setIdentifier = relay.name;
                    routingPolicy = "multivalue";
                    accessKeyId = pkgs.globals.ec2.credentials.accessKeyIds.dns;
                  }
                ))
              ] ++ (lib.genList
                (i: (nameValuePair "${relaysNewPrefix}-${relay.name}${lib.optionalString (i > 0) ".${toString i}"}-aaaa" (
                  { resources, ... }: {
                    zoneName = "${pkgs.globals.dnsZone}.";
                    domainName = "${prefix}${optionalString (prefix != "") "."}${pkgs.globals.relaysNew}.";
                    recordValues = [ resources.machines.${relay.name} ];
                    ipIndexes = [ i ];
                    recordType = "AAAA";
                    setIdentifier = "${relay.name}${lib.optionalString (i > 0) ".${toString i}"}";
                    routingPolicy = "multivalue";
                    accessKeyId = pkgs.globals.ec2.credentials.accessKeyIds.dns;
                  }
                ))
                )
                (lib.min globals.nbInstancesPerRelay (200 / (length relays))))
              )
              relays);
          in
          mkRelayRecords "" (_: true)
            // mkRelayRecords "asia-pacific" (n: hasPrefix "ap" n.region)
            // mkRelayRecords "north-america" (n: hasPrefix "us" n.region)
            // mkRelayRecords "europe" (n: hasPrefix "eu" n.region)
            // (
            let records = map
              (coreNode:
                if coreNode ? ticker
                then mkRelayRecords (toLower coreNode.ticker) (r: elem coreNode.name r.producers)
                else { }
              )
              coreNodes;
            in foldl' (a: b: a // b) { } records
          )
        );

      }
      (map
        ({ org, region }:
          let
            usedAvailabilityZones = unique (map (node: node.deployment.ec2.zone) (filter (node: node.deployment.ec2.region == region && node.node.org == org) nodeList));
          in
          {

            ec2KeyPairs."cardano-keypair-${org}-${region}" = {
              inherit region;
              accessKeyId = pkgs.globals.ec2.credentials.accessKeyIds.${org};
            };

            vpcRouteTables."route-table-${org}-${region}" =
              { resources, ... }:
              {
                inherit region; vpcId = resources.vpc."vpc-${org}-${region}";
                accessKeyId = pkgs.globals.ec2.credentials.accessKeyIds.${org};
              };

            vpcRouteTableAssociations = listToAttrs (map
              (zone: nameValuePair "association-${org}-${zone}" (
                { resources, ... }:
                {
                  inherit region;
                  subnetId = resources.vpcSubnets."subnet-${org}-${zone}";
                  routeTableId = resources.vpcRouteTables."route-table-${org}-${region}";
                  accessKeyId = pkgs.globals.ec2.credentials.accessKeyIds.${org};
                }
              ))
              usedAvailabilityZones);

            vpcRoutes."igw-route-${org}-${region}" =
              { resources, ... }:
              {
                inherit region;
                routeTableId = resources.vpcRouteTables."route-table-${org}-${region}";
                destinationCidrBlock = "0.0.0.0/0";
                gatewayId = resources.vpcInternetGateways."igw-${org}-${region}";
                accessKeyId = pkgs.globals.ec2.credentials.accessKeyIds.${org};
              };

            vpcRoutes."igw-route-ipv6-${org}-${region}" =
              { resources, ... }:
              {
                inherit region;
                routeTableId = resources.vpcRouteTables."route-table-${org}-${region}";
                destinationIpv6CidrBlock = "::/0";
                gatewayId = resources.vpcInternetGateways."igw-${org}-${region}";
                accessKeyId = pkgs.globals.ec2.credentials.accessKeyIds.${org};
              };

            vpcInternetGateways."igw-${org}-${region}" =
              { resources, ... }:
              {
                inherit region;
                vpcId = resources.vpc."vpc-${org}-${region}";
                accessKeyId = pkgs.globals.ec2.credentials.accessKeyIds.${org};
              };

            vpcSubnets = listToAttrs (lib.concatLists (lib.imap0
              (index: zone: lib.optional (lib.elem zone usedAvailabilityZones)
                (nameValuePair "subnet-${org}-${zone}" (
                  { resources, ... }:
                  {
                    inherit region zone;
                    vpcId = resources.vpc."vpc-${org}-${region}";
                    cidrBlock = "10.0.${toString (index * 32)}.0/19";
                    ipv6CidrSubnetBlock = leftPad (lib.toHexString index) 2;
                    accessKeyId = pkgs.globals.ec2.credentials.accessKeyIds.${org};
                  }
                ))
              )
              aws-regions.${region}.zones));

            vpc."vpc-${org}-${region}" = {
              inherit region;
              cidrBlock = "10.0.0.0/16";
              enableDnsSupport = true;
              enableDnsHostnames = true;
              amazonProvidedIpv6CidrBlock = true;
              accessKeyId = pkgs.globals.ec2.credentials.accessKeyIds.${org};
            };

          })
        orgXregion);

    defaults = { name, resources, config, ... }: {
      deployment.ec2 = {
        associatePublicIpAddress = true;
        ipv6AddressHostParts =
         lib.concatLists (lib.catAttrs name (lib.imap1
          (i: r: {
            "${r.name}" = lib.genList (j: ":0:${lib.toHexString i}:0:${lib.toHexString (j + 1)}") globals.nbInstancesPerRelay;
          })
          (filter
            (r: r.region == config.deployment.ec2.region
              && r.org == config.node.org
              && r.zone == config.deployment.ec2.zone)
            relayNodes) ++ [{
              "monitoring" = [":1:0:0:1"];
              "explorer" = [":2:0:0:1"];
              "metadata" = [":3:0:0:1"];
              "snapshots" = [":4:0:0:1"];
              "faucet" = [":5:0:0:1"];
            }] ++ lib.imap1 (i: e:  {
              "explorer-${e}" = [":2:${lib.toHexString i}:0:1"];
            }) (lib.attrNames globals.explorerBackends)
            ++ lib.imap1 (i: n:  {
              "${n.name}" = [":0:0:${lib.toHexString i}:1"];
            }) coreNodes));
        subnetId = resources.vpcSubnets."subnet-${config.node.org}-${config.deployment.ec2.zone}";
        keyPair = resources.ec2KeyPairs."cardano-keypair-${config.node.org}-${config.deployment.ec2.region}";
        securityGroupIds = map (sgName: resources.ec2SecurityGroups.${sgName}.name)
          (attrNames (securityGroupsByNode.${name} or { }));
      };
    };
  };
in
cluster // settings
