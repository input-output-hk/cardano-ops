with import ../nix {};
let
  inherit (pkgs.lib)
    attrValues attrNames filter filterAttrs flatten foldl' hasAttrByPath listToAttrs
    mapAttrs' mapAttrs nameValuePair recursiveUpdate unique optional any concatMap
    getAttrs optionalString hasPrefix groupBy' concatLists mapAttrsToList zipListsWith
    partition optionals head;

  inherit (globals.topology) legacyCoreNodes legacyRelayNodes byronProxies coreNodes relayNodes;
  privateRelayNodes = globals.topology.privateRelayNodes or [];
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

  securityGroups = {

    all-nodes = {
      inherit nodes;
      rules = [{
          protocol = "tcp"; # TCP
          fromPort = 22;
          toPort = 22;
          sourceIp = pkgs.globals.deployerIp + "/32";
        }] ++ optionals doMonitoring (map (p:
        {
          protocol = "tcp";
          fromPort = p;
          toPort = p;
          sourceGroup = "monitoring";
        }) ([
          9100  # prometheus exporters
          9102  # statd exporter
          9113  # nginx exporter
        ] ++ (pkgs.globals.extraPrometheusExportersPorts or [])));
    };

    core-nodes = {
      nodes = filterAttrs (_: n: n.node.roles.isCardanoCore or false) nodes;
      rules = [{
        protocol = "tcp";
        fromPort = pkgs.globals.cardanoNodePort;
        toPort = pkgs.globals.cardanoNodePort;
        sourceGroup = "relay-nodes";
      }];
    };

    relay-nodes = {
      nodes = filterAttrs (_: n: n.node.roles.isCardanoRelay or false) nodes;
      rules = [{
        protocol = "tcp";
        fromPort = pkgs.globals.cardanoNodePort;
        toPort = pkgs.globals.cardanoNodePort;
        sourceIp = "0.0.0.0/0";
      }];
    };

    monitoring = {
      nodes = filterAttrs (_: n: n.node.roles.isMonitor or false) nodes;
      rules = [{
        protocol = "tcp";
        fromPort = 5044; # graylog
        toPort = 5044;
        sourceIp = "0.0.0.0/0";
      }];
    };

    public-https = {
      nodes = filterAttrs (_: n:
        n.node.roles.isMonitor or
        n.node.roles.isExplorer or
        n.node.roles.isFaucet or false) nodes;
      rules = [
        {
          protocol = "tcp";
          fromPort = 80;
          toPort = 80;
          sourceIp = "0.0.0.0/0";
        }
        {
          protocol = "tcp";
          fromPort = 443;
          toPort = 443;
          sourceIp = "0.0.0.0/0";
        }
      ];
    };
  };

  groupsByLogicalName = mapAttrs (name: { nodes, rules ? [], ... }@group:
    let
      orgs = unique (mapAttrsToList (_: n: n.node.org) nodes);
      regions = unique (mapAttrsToList (_: n: n.deployment.ec2.region) nodes);
      splitRulesWithSg = partition (r: r ? sourceGroup) rules;
    in
      concatMap (org: map (region: nameValuePair "${name}-${org}-${region}" ({
        nodes = filterAttrs (_: n: n.node.org == org && n.deployment.ec2.region == region) nodes;
        securityGroup = { resources, ... }@args:
          let
            accessKeyId = pkgs.globals.ec2.credentials.accessKeyIds.${org};
            appliedGroup = (group.func or (_:{})) args;
            enrichedSgRules = concatMap (r: concatMap (sg: optional (sg.value.nodes != []) (r // { sourceGroup = {
                ownerId = resources.ec2SecurityGroups.${sg.name}.accessKeyId;
                groupName = resources.ec2SecurityGroups.${sg.name}.name;
              }; })) groupsByLogicalName.${r.sourceGroup}) splitRulesWithSg.right;

          in (removeAttrs group ["func"]) // appliedGroup // {
            inherit region accessKeyId;
            rules = enrichedSgRules ++ splitRulesWithSg.wrong ++ (appliedGroup.rules or []);
          };
      })) regions) orgs
    ) securityGroups;

  securityGroupsWithNodes = concatMap (filter (sg: sg.value.nodes != [])) (attrValues groupsByLogicalName);

  ec2SecurityGroups = listToAttrs (map
    ({name, value}: nameValuePair name value.securityGroup) # remove nodes, bump actual securityGroup
    securityGroupsWithNodes);

  securityGroupNodePairs = concatMap
    ({name, value}: map (nodeName: {inherit name nodeName;}) (attrNames value.nodes))
    securityGroupsWithNodes;

  securityGroupsByNode = groupBy' (sgs: sgNodePair: [sgNodePair.name] ++ sgs) []
    (sgNodePair: sgNodePair.nodeName) securityGroupNodePairs;

  settings = {
    resources = {
      inherit ec2SecurityGroups;

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
        let mkRelayRecords = prefix: relayFilter: listToAttrs (map (relay:
          nameValuePair "${prefix}${optionalString (prefix != "") "-"}relays-new-${relay.name}" (
          { resources, ... }: {
            zoneName = "${pkgs.globals.dnsZone}.";
            domainName = "${prefix}${optionalString (prefix != "") "."}${pkgs.globals.relaysNew}.";
            recordValues = [ resources.machines.${relay.name} ];
            recordType = "A";
            setIdentifier = relay.name;
            routingPolicy = "multivalue";
            accessKeyId = pkgs.globals.ec2.credentials.accessKeyIds.dns;
          })
        ) (filter relayFilter relayNodes));
        in mkRelayRecords "" (_: true)
        // mkRelayRecords "asia-pacific" (n: hasPrefix "ap" n.region)
        // mkRelayRecords "north-america" (n: hasPrefix "us" n.region)
        // mkRelayRecords "europe" (n: hasPrefix "eu" n.region);
    };
    defaults = { name, resources, config, ... }: {
      deployment.ec2 = {
        keyPair = resources.ec2KeyPairs."cardano-keypair-${config.node.org}-${config.deployment.ec2.region}";
        securityGroups = lib.mkIf (securityGroupsByNode ? ${name})
          (map (sgName: resources.ec2SecurityGroups.${sgName}) securityGroupsByNode.${name});
      };
    };
  };
in
  cluster // settings
