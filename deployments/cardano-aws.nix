with import ../nix {};
let
  inherit (pkgs.lib)
    attrValues attrNames filter filterAttrs flatten foldl' hasAttrByPath listToAttrs
    mapAttrs' mapAttrs nameValuePair recursiveUpdate unique optional any concatMap
    getAttrs optionalString hasPrefix take drop length concatStringsSep head toLower
    elem;

  inherit (globals.topology) coreNodes relayNodes;
  privateRelayNodes = globals.topology.privateRelayNodes or [];
  inherit (globals.ec2.credentials) accessKeyIds;
  inherit (iohk-ops-lib.physical) aws;

  cluster = import ../clusters/cardano.nix {
    inherit pkgs;
    inherit (globals.ec2) instances;
  };

  nodes = filterAttrs (name: node:
    ((node.deployment.targetEnv or null) == "ec2")
    && ((node.deployment.ec2.region or null) != null)) cluster;

  doMonitoring = any (n: n.node.roles.isMonitor or false) (attrValues nodes);

  regions =
    unique (map (node: node.deployment.ec2.region) (attrValues nodes));

  orgs =
    unique (map (node: node.node.org) (attrValues nodes));

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
      nodes = (filterAttrs (_: n: n.node.roles.isSmash or false) nodes);
      groups = [ allow-public-www-https ];
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

  importSecurityGroup =  node: securityGroup:
    securityGroup {
      inherit pkgs lib nodes;
      region = node.deployment.ec2.region;
      org = node.node.org;
      accessKeyId = pkgs.globals.ec2.credentials.accessKeyIds.${node.node.org};
    };


  importSecurityGroups = {nodes, groups}:
    mapAttrs
      (_: n: foldl' recursiveUpdate {} (map (importSecurityGroup n) groups))
      nodes;

  securityGroupsByNode =
    foldl' recursiveUpdate {} (map importSecurityGroups securityGroups);

  settings = {
    resources = {
      ec2SecurityGroups =
        foldl' recursiveUpdate {} (attrValues securityGroupsByNode);

      elasticIPs = mapAttrs' (name: node:
        nameValuePair "${name}-ip" {
          accessKeyId = accessKeyIds.${node.node.org};
          inherit (node.deployment.ec2) region;
        }) nodes;

      ec2KeyPairs = listToAttrs (concatMap (region:
        map (org:
          nameValuePair "cardano-keypair-${org}-${region}" {
            inherit region;
            accessKeyId = pkgs.globals.ec2.credentials.accessKeyIds.${org};
          }
        ) orgs)
        regions);

      route53RecordSets =
        let mkRelayRecords = prefix: let
          relaysNewPrefix = "${prefix}${optionalString (prefix != "") "-"}relays-new";
        in relayFilter: listToAttrs (map (relay:
          nameValuePair "${relaysNewPrefix}-${relay.name}" (
          { resources, ... }: {
            zoneName = "${pkgs.globals.dnsZone}.";
            domainName = "${prefix}${optionalString (prefix != "") "."}${pkgs.globals.relaysNew}.";
            recordValues = [ resources.machines.${relay.name} ];
            recordType = "A";
            setIdentifier = relay.name;
            routingPolicy = "multivalue";
            accessKeyId = pkgs.globals.ec2.credentials.accessKeyIds.dns;
          })
          # AWS records are limited to 200 values:
        ) (let relays = filter relayFilter relayNodes;
          numberOfRelays = length relays;
        in if (numberOfRelays > 200) then builtins.trace
          "WARNING: Getting over the 200 values limit for ${relaysNewPrefix} dns entry (${toString numberOfRelays} relays). Excluding ${concatStringsSep " " (map (r: r.name) (drop 200 relays))}."
          (take 200 relays)
        else relays));
        in mkRelayRecords "" (_: true)
          // mkRelayRecords "asia-pacific" (n: hasPrefix "ap" n.region)
          // mkRelayRecords "north-america" (n: hasPrefix "us" n.region)
          // mkRelayRecords "europe" (n: hasPrefix "eu" n.region)
          // (
            let records = map (coreNode: if coreNode ? ticker
              then mkRelayRecords (toLower coreNode.ticker) (r: elem coreNode.name r.producers)
              else {}
            ) coreNodes;
            in foldl' (a: b: a // b) {} records);

    };
    defaults = { name, resources, config, ... }: {
      deployment.ec2 = {
        keyPair = resources.ec2KeyPairs."cardano-keypair-${config.node.org}-${config.deployment.ec2.region}";
        securityGroups = map (sgName: resources.ec2SecurityGroups.${sgName})
          (attrNames (securityGroupsByNode.${name} or {}));
      };
    };
  };
in
  cluster // settings
