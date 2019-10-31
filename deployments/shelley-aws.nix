with import ../nix {};
let
  inherit (lib)
    attrValues filter filterAttrs flatten foldl' hasAttrByPath listToAttrs
    mapAttrs' nameValuePair recursiveUpdate unique;

  inherit (globals.ec2) credentials;
  inherit (credentials) accessKeyId;
  inherit (iohk-ops-lib.physical) aws;

  cluster = import ../clusters/shelley.nix {
    inherit (aws) targetEnv;
    tiny = aws.t2nano;
    medium = aws.t2xlarge;
    large = aws.t3xlarge;
  };

  nodes = filterAttrs (name: node:
    ((node.deployment.targetEnv or null) == "ec2")
    && ((node.deployment.ec2.region or null) != null)) cluster;

  regions =
    unique (map (node: node.deployment.ec2.region) (attrValues nodes));

  securityGroups = with aws.security-groups; [
    allow-all
    allow-ssh
    # allow-deployer-ssh
    (allow-monitoring-collection {})
    allow-public-www-https
    allow-graylog
  ];

  importSecurityGroup = region: securityGroup:
    securityGroup { inherit lib region accessKeyId nodes; };

  mkEC2SecurityGroup = region:
    foldl' recursiveUpdate { }
    (map (importSecurityGroup region) securityGroups);

  settings = {
    resources = {
      ec2SecurityGroups =
        foldl' recursiveUpdate { } (map mkEC2SecurityGroup regions);

      elasticIPs = mapAttrs' (name: node:
        nameValuePair "${name}-ip" {
          inherit accessKeyId;
          inherit (node.deployment.ec2) region;
        }) nodes;

      ec2KeyPairs = listToAttrs (map (region:
        nameValuePair "${globals.deploymentName}-${region}" { inherit region accessKeyId; })
        regions);
    };
  };
in
  cluster // settings
