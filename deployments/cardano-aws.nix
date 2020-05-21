with import ../nix {};
let
  inherit (pkgs.lib)
    attrValues attrNames filter filterAttrs flatten foldl' hasAttrByPath listToAttrs
    mapAttrs' mapAttrs nameValuePair recursiveUpdate unique optional any concatMap
    getAttrs;

  inherit (globals.topology) legacyCoreNodes legacyRelayNodes byronProxies coreNodes relayNodes;
  inherit (globals.ec2.credentials) accessKeyIds;
  inherit (iohk-ops-lib.physical) aws;

  cluster = import ../clusters/cardano.nix {
    inherit pkgs;
    inherit (aws) targetEnv;
    nano = aws.t3a-nano;
    small = aws.t3a-small;
    medium = aws.t3a-medium;                     # Standard relay
    xlarge = aws.t3a-xlarge;                     # Standard explorer
    t3-xlarge = aws.t3-xlarge;                   # High load relay
    m5ad-xlarge = aws.m5ad-xlarge;               # Test node
    xlarge-monitor = aws.t3a-xlargeMonitor;      # Standard monitor
    t3-2xlarge-monitor = aws.t3-2xlargeMonitor;  # High capacity monitor, explorer
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
      nodes = getAttrs (map (n: n.name) (legacyCoreNodes ++ byronProxies)) nodes;
      groups = [ (import ../physical/aws/security-groups/allow-legacy-peers.nix) ];
    }
    {
      nodes = getAttrs (map (n: n.name) legacyRelayNodes) nodes;
      groups = [ (import ../physical/aws/security-groups/allow-legacy-public.nix) ];
    }
    {
      nodes = getAttrs (map (n: n.name) (coreNodes ++ byronProxies)) nodes;
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
      nodes = (filterAttrs (_: n: n.node.roles.isFaucet or false) nodes);
      groups = [ allow-public-www-https ];
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

      route53RecordSets = listToAttrs (map (relay: nameValuePair "relays-new-${relay.name}" (
        { resources, ... }: {
          zoneName = "${pkgs.globals.dnsZone}.";
          domainName = "relays-new.${pkgs.globals.domain}.";
          recordValues = [ resources.machines.${relay.name} ];
          recordType = "A";
          setIdentifier = relay.name;
          routingPolicy = "multivalue";
          accessKeyId = pkgs.globals.ec2.credentials.accessKeyIds.dns;
        })
      ) relayNodes);
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
