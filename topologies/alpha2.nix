{pkgs, lib, ...}:
with lib;
let
  regions = {
    a = "eu-central-1";
    b = "ap-northeast-1";
    c = "ap-southeast-1";
    d = "us-east-2";
    e = "eu-west-1";
    f = "eu-west-2";
    g = "eu-central-1"; # does not work for some reason: "eu-west-3";
    h = "us-east-1";
    i = "us-west-1";
    j = "us-west-2";
    k = "ca-central-1";
    l = "ap-southeast-2";
    m = "ap-northeast-2";
    n = "ap-south-1";
  };
  nodeIndexesInRegion = builtins.genList (i: i + 1) 7;
  regionLetters = (attrNames regions);
  indexedRegions = imap1 (rIndex: rLetter:
    { inherit rIndex rLetter;
      region = getAttr rLetter regions; }
  ) regionLetters;
  allProducers = concatMap (i: map (rLetter: "c-${rLetter}-${toString i}") regionLetters) nodeIndexesInRegion;
in {
  legacyCoreNodes = [];
  legacyRelayNodes = [];
  byronProxies = [];
  relayNodes = [];

  coreNodes = builtins.concatMap (nodeIndex:
      map ({rLetter, rIndex, region}:
        let
          name = "c-${rLetter}-${toString nodeIndex}";
        in {
          inherit region name;
          producers = let allProducersExceptMe = filter (n: n != name) allProducers;
            in if (name == "c-a-1") then
              lib.take 5 allProducersExceptMe
            else if (name == "c-b-1") then
              lib.take 10 allProducersExceptMe
            else if (name == "c-c-1") then
              lib.take 20 allProducersExceptMe
            else if (name == "c-d-1") then
              lib.take 40 allProducersExceptMe
            else if (name == "c-e-1") then
              lib.take 60 allProducersExceptMe
            else if (name == "c-f-1") then
              lib.take 80 allProducersExceptMe
            else if (name == "c-g-1") then
              lib.take 5 allProducersExceptMe
            else allProducersExceptMe;
          org = "IOHK";
          nodeId =  nodeIndex * rIndex;
          services.monitoring-exporters.enable =
            # Only monitor one node per region:
            if (nodeIndex == 1) then true else false;
          } // (optionalAttrs (name == "c-g-1" || name == "c-g-2") {
            services.cardano-node.profiling = "space";
          })
      ) indexedRegions
  ) nodeIndexesInRegion;
}
