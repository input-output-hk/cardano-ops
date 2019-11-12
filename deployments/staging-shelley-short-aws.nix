with import ../nix {};
let
  inherit (lib)
    attrValues filter filterAttrs flatten foldl' hasAttrByPath listToAttrs
    mapAttrs' nameValuePair recursiveUpdate unique;

  inherit (globals.ec2) credentials;
  inherit (credentials) accessKeyId;
  inherit (iohk-ops-lib.physical) aws;

  cluster = import ../clusters/staging-shelley-short.nix {
    inherit (aws) targetEnv;
    tiny = aws.t2nano;
    medium = aws.t2xlarge;
    large = aws.t2large;
  };

  nodes = filterAttrs (name: node:
    ((node.deployment.targetEnv or null) == "ec2")
    && ((node.deployment.ec2.region or null) != null)) cluster;

  cardanoLegacyNodes = lib.traceValFn (x: (__trace "CardanoLegacyNodes:" __attrNames x))
    (filterAttrs (name: node:
      (node.node.isCardanoLegacyCore or false)
      || (node.node.isCardanoLegacyRelay or false)) cluster);

  regions =
    unique (map (node: node.deployment.ec2.region) (attrValues nodes));

  securityGroups = with aws.security-groups; [
    allow-all
    allow-ssh
    # allow-deployer-ssh
    allow-monitoring-collection
    allow-public-www-https
    allow-graylog
    allow-cardano-legacy-node
  ];

  importSecurityGroup = region: securityGroup:
    securityGroup { inherit lib region accessKeyId cardanoLegacyNodes nodes; };

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

      ec2KeyPairs = listToAttrs (__concatLists (map (region:
        [
          (nameValuePair "cardano-keypair-IOHK-${region}" { inherit region accessKeyId; })
          (nameValuePair "cardano-keypair-CF-${region}" { inherit region accessKeyId; })
          (nameValuePair "cardano-keypair-Emurgo-${region}" { inherit region accessKeyId; })
        ])
        regions));
    };
    defaults = { resources, config, ... }: {
      deployment.ec2.keyPair = resources.ec2KeyPairs."cardano-keypair-${config.node.org}-${config.deployment.ec2.region}";
    };
  };
in
  cluster // settings
