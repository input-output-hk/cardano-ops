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
    inherit (aws) targetEnv;
    tiny = aws.t2nano;
    medium = aws.t2large;
    large = aws.t2xlarge;
  };

  nodes = filterAttrs (name: node:
    ((node.deployment.targetEnv or null) == "ec2")
    && ((node.deployment.ec2.region or null) != null)) cluster;

  regions =
    unique (map (node: node.deployment.ec2.region) (attrValues nodes));

  orgs =
    unique (map (node: node.node.org) (attrValues nodes));

  securityGroups = with aws.security-groups; [
    {
      nodes = getAttrs (map (n: n.name) legacyCoreNodes) nodes;
      groups = [ (import ../physical/aws/security-groups/allow-legacy-peers.nix) ];
    }
    {
      nodes = getAttrs (map (n: n.name) (legacyRelayNodes ++ byronProxies)) nodes;
      groups = [ (import ../physical/aws/security-groups/allow-legacy-public.nix) ];
    }
    {
      nodes = getAttrs (map (n: n.name) coreNodes) nodes;
      groups = [ (import ../physical/aws/security-groups/allow-peers.nix) ];
    }
    {
      nodes = getAttrs (map (n: n.name) (relayNodes ++ byronProxies)) nodes;
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
      inherit nodes;
      groups = [
        allow-deployer-ssh
      ]
      ++ optional (any (n: n.node.roles.isMonitor or false) (attrValues nodes))
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
