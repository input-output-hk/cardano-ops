pkgs: with pkgs; with lib; with topology-lib;
let

  withAutoRestart = def: lib.recursiveUpdate {
    systemd.services.cardano-node.serviceConfig = {
      RuntimeMaxSec = 6 *
        60 * 60 + 60 * (5 * (def.nodeId or 0));
    };
  } def;

  regions = {
    a = { name = "eu-central-1";   # Europe (Frankfurt);
      minRelays = 2;
    };
    b = { name = "us-east-2";      # US East (Ohio)
      minRelays = 2;
    };
    c = { name = "ap-southeast-1"; # Asia Pacific (Singapore)
      minRelays = 2;
    };
    d = { name = "eu-west-2";      # Europe (London)
      minRelays = 25;
    };
    e = { name = "us-west-1";      # US West (N. California)
      minRelays = 25;
    };
    f = { name = "ap-northeast-1"; # Asia Pacific (Tokyo)
      minRelays = 2;
    };
  };

  bftCoreNodes = [
    # OBFT centralized nodes
    {
      name = "bft-a-1";
      region = regions.a.name;
      producers = map (c: c.name) coreNodes ++ [ "rel-a-1" "rel-a-3" ];
      org = "IOHK";
      nodeId = 1;
    }
    {
      name = "bft-b-1";
      region = regions.b.name;
      producers = map (c: c.name) coreNodes ++ [ "rel-b-1" "rel-b-3" ];
      org = "IOHK";
      nodeId = 2;
    }
    {
      name = "bft-f-1";
      region = regions.f.name;
      producers = map (c: c.name) coreNodes ++ [ "rel-f-1" "rel-f-3" ];
      org = "Emurgo";
      nodeId = 3;
    }
    {
      name = "bft-f-2";
      region = regions.f.name;
      producers = map (c: c.name) coreNodes ++ [ "rel-f-2" "rel-f-4" ];
      org = "Emurgo";
      nodeId = 4;
    }
    {
      name = "bft-c-1";
      region = regions.c.name;
      producers = map (c: c.name) coreNodes ++ [ "rel-c-1" "rel-c-3" ];
      org = "CF";
      nodeId = 5;
    }
    {
      name = "bft-c-2";
      region = regions.c.name;
      producers = map (c: c.name) coreNodes ++ [ "rel-c-2" "rel-c-4" ];
      org = "CF";
      nodeId = 6;
    }
    {
      name = "bft-d-1";
      region = regions.d.name;
      producers = map (c: c.name) coreNodes ++ [ "rel-d-1" "rel-d-2" ];
      org = "IOHK";
      nodeId = 7;
    }
  ];

  stakingPoolNodes = [
    {
      name = "stk-a-1";
      region = regions.a.name;
      producers = map (c: c.name) coreNodes ++ [ "rel-a-2" "rel-a-4" ];
      org = "IOHK";
      nodeId = 8;
    }
    {
      name = "stk-b-1";
      region = regions.b.name;
      producers = map (c: c.name) coreNodes ++ [ "rel-c-1" "rel-c-2" ];
      org = "IOHK";
      nodeId = 9;
    }
    {
      name = "stk-e-1";
      region = regions.e.name;
      producers = map (c: c.name) coreNodes ++ [ "rel-e-1" "rel-e-1" ];
      org = "IOHK";
      nodeId = 10;
    }
  ];

  coreNodes = bftCoreNodes ++ stakingPoolNodes;

  londonRelayNodes = mkRelayTopology {
    regions = { inherit (regions) d; };
    coreNodes = filter (r: r.region == regions.a.name) oldRelayNodes;
  };

  californiaRelayNodes = mkRelayTopology {
     regions = { inherit (regions) e; };
     coreNodes = filter (r: r.region == regions.b.name) oldRelayNodes;
  };

  oldCoreNodes = [
    {
      name = "c-a-1";
      region = "eu-central-1";
      producers = [
        "c-a-2"
        "c-b-1" "c-c-1" "c-d-1"
        "e-a-1" "e-a-3" "e-a-5"
        "e-b-7" "e-c-7" "e-d-4"
        "rel-d-1"
      ];
      org = "IOHK";
      nodeId = 1;
    }
    {
      name = "c-a-2";
      region = "eu-central-1";
      producers = [
        "c-a-1"
        "c-b-2" "c-c-2"
        "e-a-2" "e-a-4" "e-a-6"
        "e-b-8" "e-c-8" "e-d-5"
        "rel-d-2"
      ];
      org = "IOHK";
      nodeId = 2;
    }
    {
      name = "c-b-1";
      region = "ap-northeast-1";
      producers = [
        "b-b-1"
        "c-b-2"
        "c-a-1" "c-c-1" "c-d-1"
        "e-b-1" "e-b-3" "e-b-5"
        "e-a-7" "e-c-9" "e-d-6"
      ];
      org = "Emurgo";
      nodeId = 3;
    }
    {
      name = "c-b-2";
      region = "ap-northeast-1";
      producers = [
        "b-b-1"
        "c-b-1"
        "c-a-2" "c-c-2"
        "e-b-2" "e-b-4" "e-b-6"
        "e-a-8" "e-c-10" "e-d-7"
      ];
      org = "Emurgo";
      nodeId = 4;
    }
    {
      name = "c-c-1";
      region = "ap-southeast-1";
      producers = [
        "b-c-1"
        "c-c-2"
        "c-a-1" "c-b-1" "c-d-1"
        "e-c-1" "e-c-3" "e-c-5"
        "e-a-9" "e-b-9" "e-d-8"
      ];
      org = "CF";
      nodeId = 5;
    }
    {
      name = "c-c-2";
      region = "ap-southeast-1";
      producers = [
        "b-c-1"
        "c-c-1"
        "c-a-2" "c-b-2"
        "e-c-2" "e-c-4" "e-c-6"
        "e-a-10" "e-b-10" "e-d-9"
      ];
      org = "CF";
      nodeId = 6;
    }
    {
      name = "c-d-1";
      region = "us-east-2";
      producers = [
        "c-a-2" "c-b-2" "c-d-2"
        "e-d-1" "e-d-2" "e-d-3"
        "e-a-11" "e-b-11" "e-c-11"
        "rel-e-1"
      ];
      org = "IOHK";
      nodeId = 7;
    }
  ];

  # Recovery nodes:
  withTestShelleyHardForkAtVersion3 = lib.recursiveUpdate {
    services.cardano-node.nodeConfig = {
      TestShelleyHardForkAtVersion = 3;
    };
  };

  recoveryCoreNodes =
    let mkCoreNode = r: idx: attrs:
      rec {
        name = "bft-dr-${r}-${toString idx}";
        region = regions.${r}.name;
        producers = filter (n: n != name) (map (c: c.name) recoveryCoreNodes);
      } // attrs;
    in
   map withTestShelleyHardForkAtVersion3 [
    # OBFT centralized nodes recovery nodes
    (mkCoreNode "a" 1 {
      org = "IOHK";
      nodeId = 1;
    })
    (mkCoreNode "a" 2 {
      org = "IOHK";
      nodeId = 2;
    })
    (mkCoreNode "f" 1 {
      org = "Emurgo";
      nodeId = 3;
    })
    (mkCoreNode "f" 2 {
      org = "Emurgo";
      nodeId = 4;
    })
    (mkCoreNode "c" 1 {
      org = "CF";
      nodeId = 5;
    })
    (mkCoreNode "c" 2 {
      org = "CF";
      nodeId = 6;
    })
    (mkCoreNode "b" 1 {
      org = "IOHK";
      nodeId = 1;
    })
  ];

  oldRelayNodes = [

    # e-a-1 - 5 edge nodes

    {
      name = "e-a-1";
      region = "eu-central-1";
      org = "IOHK";
      nodeId = 8;
      producers = [ "c-a-2" "e-a-6" "e-a-11" "e-a-16" "e-a-21" "e-b-1" "e-c-1" "e-d-1" "rel-d-1" ];
    }
    {
      name = "e-a-2";
      region = "eu-central-1";
      org = "IOHK";
      nodeId = 19;
      producers = [ "c-a-2" "e-a-7" "e-a-12" "e-a-17" "e-a-22" "e-b-2" "e-c-2" "e-d-2" "rel-d-2" ];
    }
    {
      name = "e-a-3";
      region = "eu-central-1";
      org = "IOHK";
      nodeId = 20;
      producers = [ "c-a-2" "e-a-8" "e-a-13" "e-a-18" "e-a-23" "e-b-3" "e-c-3" "e-d-3" "rel-d-3" ];
    }
    {
      name = "e-a-4";
      region = "eu-central-1";
      org = "IOHK";
      nodeId = 21;
      producers = [ "c-a-2" "e-a-9" "e-a-14" "e-a-19" "e-a-24" "e-b-4" "e-c-4" "e-d-4" "rel-d-4" ];
    }
    {
      name = "e-a-5";
      region = "eu-central-1";
      org = "IOHK";
      nodeId = 22;
      producers = [ "c-a-2" "e-a-10" "e-a-15" "e-a-20" "e-a-25" "e-b-5" "e-c-5" "e-d-5" "rel-d-5" ];
    }

    # e-a-6 - 10 edge nodes

    {
      name = "e-a-6";
      region = "eu-central-1";
      org = "IOHK";
      nodeId = 101;
      producers = [ "c-a-1" "e-a-1" "e-a-11" "e-a-16" "e-a-21" "e-b-6" "e-c-6" "e-d-6" "rel-d-6" ];
    }
    {
      name = "e-a-7";
      region = "eu-central-1";
      org = "IOHK";
      nodeId = 102;
      producers = [ "c-a-1" "e-a-2" "e-a-12" "e-a-17" "e-a-22" "e-b-7" "e-c-7" "e-d-7" "rel-d-7" ];
    }
    {
      name = "e-a-8";
      region = "eu-central-1";
      org = "IOHK";
      nodeId = 103;
      producers = [ "c-a-1" "e-a-3" "e-a-13" "e-a-18" "e-a-23" "e-b-8" "e-c-8" "e-d-8" "rel-d-8" ];
    }
    {
      name = "e-a-9";
      region = "eu-central-1";
      org = "IOHK";
      nodeId = 104;
      producers = [ "c-a-1" "e-a-4" "e-a-14" "e-a-19" "e-a-24" "e-b-9" "e-c-9" "e-d-9" "rel-d-9" ];
    }
    {
      name = "e-a-10";
      region = "eu-central-1";
      org = "IOHK";
      nodeId = 105;
      producers = [ "c-a-1" "e-a-5" "e-a-15" "e-a-20" "e-a-25" "e-b-10" "e-c-10" "e-d-10" "rel-d-10" ];
    }
    # e-a-11 - 15 edge nodes
    {
      name = "e-a-11";
      region = "eu-central-1";
      org = "IOHK";
      nodeId = 106;
      producers = [ "e-a-1" "e-a-6" "e-a-16" "e-a-21" "e-b-11" "e-c-11" "e-d-11" "rel-d-11" ];
    }
    {
      name = "e-a-12";
      region = "eu-central-1";
      org = "IOHK";
      nodeId = 107;
      producers = [ "e-a-2" "e-a-7" "e-a-17" "e-a-22" "e-b-12" "e-c-12" "e-d-12" "rel-d-12" ];
    }
    {
      name = "e-a-13";
      region = "eu-central-1";
      org = "IOHK";
      nodeId = 108;
      producers = [ "e-a-3" "e-a-8" "e-a-18" "e-a-23" "e-b-13" "e-c-13" "e-d-13" "rel-d-13" ];
    }
    {
      name = "e-a-14";
      region = "eu-central-1";
      org = "IOHK";
      nodeId = 109;
      producers = [ "e-a-4" "e-a-9" "e-a-19" "e-a-24" "e-b-14" "e-c-14" "e-d-14" "rel-d-14" ];
    }
    {
      name = "e-a-15";
      region = "eu-central-1";
      org = "IOHK";
      nodeId = 110;
      producers = [ "e-a-5" "e-a-10" "e-a-20" "e-a-25" "e-b-15" "e-c-15" "e-d-15" "rel-d-15" ];
    }
    # e-a-16 - 20 edge nodes
    {
      name = "e-a-16";
      region = "eu-central-1";
      org = "IOHK";
      nodeId = 111;
      producers = [ "e-a-1" "e-a-6" "e-a-11" "e-a-21" "e-b-16" "e-c-16" "e-d-16" "rel-d-16" ];
    }
    {
      name = "e-a-17";
      region = "eu-central-1";
      org = "IOHK";
      nodeId = 112;
      producers = [ "e-a-2" "e-a-7" "e-a-12" "e-a-22" "e-b-17" "e-c-17" "e-d-17" "rel-d-17" ];
    }
    {
      name = "e-a-18";
      region = "eu-central-1";
      org = "IOHK";
      nodeId = 113;
      producers = [ "e-a-3" "e-a-8" "e-a-13" "e-a-23" "e-b-18" "e-c-18" "e-d-18" "rel-d-18" ];
    }
    {
      name = "e-a-19";
      region = "eu-central-1";
      org = "IOHK";
      nodeId = 114;
      producers = [ "e-a-4" "e-a-9" "e-a-14" "e-a-24" "e-b-19" "e-c-19" "e-d-19" "rel-d-19" ];
    }
    {
      name = "e-a-20";
      region = "eu-central-1";
      org = "IOHK";
      nodeId = 115;
      producers = [ "e-a-5" "e-a-10" "e-a-15" "e-a-25" "e-b-20" "e-c-20" "e-d-20" "rel-d-20" ];
    }
    # e-a-21 - 25 edge nodes
    {
      name = "e-a-21";
      region = "eu-central-1";
      org = "IOHK";
      nodeId = 116;
      producers = [ "e-a-1" "e-a-6" "e-a-11" "e-a-16" "e-b-21" "e-c-21" "e-d-21" "rel-d-21" ];
    }
    {
      name = "e-a-22";
      region = "eu-central-1";
      org = "IOHK";
      nodeId = 117;
      producers = [ "e-a-2" "e-a-7" "e-a-12" "e-a-17" "e-b-22" "e-c-22" "e-d-22" "rel-d-22" ];
    }
    {
      name = "e-a-23";
      region = "eu-central-1";
      org = "IOHK";
      nodeId = 118;
      producers = [ "e-a-3" "e-a-8" "e-a-13" "e-a-18" "e-b-23" "e-c-23" "e-d-23" "rel-d-23" ];
    }
    {
      name = "e-a-24";
      region = "eu-central-1";
      org = "IOHK";
      nodeId = 119;
      producers = [ "e-a-4" "e-a-9" "e-a-14" "e-a-19" "e-b-24" "e-c-24" "e-d-24" "rel-d-24" ];
    }
    {
      name = "e-a-25";
      region = "eu-central-1";
      org = "IOHK";
      nodeId = 120;
      producers = [ "e-a-5" "e-a-10" "e-a-15" "e-a-20" "e-b-25" "e-c-25" "e-d-25" "rel-d-25" ];
    }

    # e-b-1 - 5 edge nodes

    {
      name = "e-b-1";
      region = "ap-northeast-1";
      org = "IOHK";
      nodeId = 9;
      producers = [ "c-b-2" "e-b-6" "e-b-11" "e-b-16" "e-b-21" "e-a-1" "e-c-1" "e-d-1" ];
    }
    {
      name = "e-b-2";
      region = "ap-northeast-1";
      org = "IOHK";
      nodeId = 23;
      producers = [ "c-b-2" "e-b-7" "e-b-12" "e-b-17" "e-b-22" "e-a-2" "e-c-2" "e-d-2" ];
    }
    {
      name = "e-b-3";
      region = "ap-northeast-1";
      org = "IOHK";
      nodeId = 24;
      producers = [ "c-b-2" "e-b-8" "e-b-13" "e-b-18" "e-b-23" "e-a-3" "e-c-3" "e-d-3" ];
    }
    {
      name = "e-b-4";
      region = "ap-northeast-1";
      org = "IOHK";
      nodeId = 25;
      producers = [ "c-b-2" "e-b-9" "e-b-14" "e-b-19" "e-b-24" "e-a-4" "e-c-4" "e-d-4" ];
    }
    {
      name = "e-b-5";
      region = "ap-northeast-1";
      org = "IOHK";
      nodeId = 26;
      producers = [ "c-b-2" "e-b-10" "e-b-15" "e-b-20" "e-b-25" "e-a-5" "e-c-5" "e-d-5" ];
    }

    # e-b-6 - 10 edge nodes

    {
      name = "e-b-6";
      region = "ap-northeast-1";
      org = "IOHK";
      nodeId = 121;
      producers = [ "c-b-1" "e-b-1" "e-b-11" "e-b-16" "e-b-21" "e-a-6" "e-c-6" "e-d-6" ];
    }
    {
      name = "e-b-7";
      region = "ap-northeast-1";
      org = "IOHK";
      nodeId = 122;
      producers = [ "c-b-1" "e-b-2" "e-b-12" "e-b-17" "e-b-22" "e-a-7" "e-c-7" "e-d-7" ];
    }
    {
      name = "e-b-8";
      region = "ap-northeast-1";
      org = "IOHK";
      nodeId = 123;
      producers = [ "c-b-1" "e-b-3" "e-b-13" "e-b-18" "e-b-23" "e-a-8" "e-c-8" "e-d-8" ];
    }
    {
      name = "e-b-9";
      region = "ap-northeast-1";
      org = "IOHK";
      nodeId = 124;
      producers = [ "c-b-1" "e-b-4" "e-b-14" "e-b-19" "e-b-24" "e-a-9" "e-c-9" "e-d-9" ];
    }
    {
      name = "e-b-10";
      region = "ap-northeast-1";
      org = "IOHK";
      nodeId = 125;
      producers = [ "c-b-1" "e-b-5" "e-b-15" "e-b-20" "e-b-25" "e-a-10" "e-c-10" "e-d-10" ];
    }
    # e-b-11 - 15 edge nodes
    {
      name = "e-b-11";
      region = "ap-northeast-1";
      org = "IOHK";
      nodeId = 126;
      producers = [ "e-b-1" "e-b-6" "e-b-16" "e-b-21" "e-a-11" "e-c-11" "e-d-11" ];
    }
    {
      name = "e-b-12";
      region = "ap-northeast-1";
      org = "IOHK";
      nodeId = 127;
      producers = [ "e-b-2" "e-b-7" "e-b-17" "e-b-22" "e-a-12" "e-c-12" "e-d-12" ];
    }
    {
      name = "e-b-13";
      region = "ap-northeast-1";
      org = "IOHK";
      nodeId = 128;
      producers = [ "e-b-3" "e-b-8" "e-b-18" "e-b-23" "e-a-13" "e-c-13" "e-d-13" ];
    }
    {
      name = "e-b-14";
      region = "ap-northeast-1";
      org = "IOHK";
      nodeId = 129;
      producers = [ "e-b-4" "e-b-9" "e-b-19" "e-b-24" "e-a-14" "e-c-14" "e-d-14" ];
    }
    {
      name = "e-b-15";
      region = "ap-northeast-1";
      org = "IOHK";
      nodeId = 130;
      producers = [ "e-b-5" "e-b-10" "e-b-20" "e-b-25" "e-a-15" "e-c-15" "e-d-15" ];
    }
    # e-b-16 - 20 edge nodes
    {
      name = "e-b-16";
      region = "ap-northeast-1";
      org = "IOHK";
      nodeId = 131;
      producers = [ "e-b-1" "e-b-6" "e-b-11" "e-b-21" "e-a-16" "e-c-16" "e-d-16" ];
    }
    {
      name = "e-b-17";
      region = "ap-northeast-1";
      org = "IOHK";
      nodeId = 132;
      producers = [ "e-b-2" "e-b-7" "e-b-12" "e-b-22" "e-a-17" "e-c-17" "e-d-17" ];
    }
    {
      name = "e-b-18";
      region = "ap-northeast-1";
      org = "IOHK";
      nodeId = 133;
      producers = [ "e-b-3" "e-b-8" "e-b-13" "e-b-23" "e-a-18" "e-c-18" "e-d-18" ];
    }
    {
      name = "e-b-19";
      region = "ap-northeast-1";
      org = "IOHK";
      nodeId = 134;
      producers = [ "e-b-4" "e-b-9" "e-b-14" "e-b-24" "e-a-19" "e-c-19" "e-d-19" ];
    }
    {
      name = "e-b-20";
      region = "ap-northeast-1";
      org = "IOHK";
      nodeId = 135;
      producers = [ "e-b-5" "e-b-10" "e-b-15" "e-b-25" "e-a-20" "e-c-20" "e-d-20" ];
    }
    # e-b-21 - 25 edge nodes
    {
      name = "e-b-21";
      region = "ap-northeast-1";
      org = "IOHK";
      nodeId = 136 ;
      producers = [ "e-b-1" "e-b-6" "e-b-11" "e-b-16" "e-a-21" "e-c-21" "e-d-21" ];
    }
    {
      name = "e-b-22";
      region = "ap-northeast-1";
      org = "IOHK";
      nodeId = 137;
      producers = [ "e-b-2" "e-b-7" "e-b-12" "e-b-17" "e-a-22" "e-c-22" "e-d-22" ];
    }
    {
      name = "e-b-23";
      region = "ap-northeast-1";
      org = "IOHK";
      nodeId = 138;
      producers = [ "e-b-3" "e-b-8" "e-b-13" "e-b-18" "e-a-23" "e-c-23" "e-d-23" ];
    }
    {
      name = "e-b-24";
      region = "ap-northeast-1";
      org = "IOHK";
      nodeId = 139;
      producers = [ "e-b-4" "e-b-9" "e-b-14" "e-b-19" "e-a-24" "e-c-24" "e-d-24" ];
    }
    {
      name = "e-b-25";
      region = "ap-northeast-1";
      org = "IOHK";
      nodeId = 140;
      producers = [ "e-b-5" "e-b-10" "e-b-15" "e-b-20" "e-a-25" "e-c-25" "e-d-25" ];
    }

    # e-c-1 - 5 edge nodes

    {
      name = "e-c-1";
      region = "ap-southeast-1";
      org = "IOHK";
      nodeId = 11;
      producers = [ "c-c-1" "e-c-6" "e-c-11" "e-c-16" "e-c-21" "e-a-1" "e-b-1" "e-d-1" ];
    }
    {
      name = "e-c-2";
      region = "ap-southeast-1";
      org = "IOHK";
      nodeId = 27;
      producers = [ "c-c-2" "e-c-7" "e-c-12" "e-c-17" "e-c-22" "e-a-2" "e-b-2" "e-d-2" ];
    }
    {
      name = "e-c-3";
      region = "ap-southeast-1";
      org = "IOHK";
      nodeId = 28;
      producers = [ "c-c-1" "e-c-8" "e-c-13" "e-c-18" "e-c-23" "e-a-3" "e-b-3" "e-d-3" ];
    }
    {
      name = "e-c-4";
      region = "ap-southeast-1";
      org = "IOHK";
      nodeId = 29;
      producers = [ "c-c-2" "e-c-9" "e-c-14" "e-c-19" "e-c-24" "e-a-4" "e-b-4" "e-d-4" ];
    }
    {
      name = "e-c-5";
      region = "ap-southeast-1";
      org = "IOHK";
      nodeId = 30;
      producers = [ "c-c-1" "e-c-10" "e-c-15" "e-c-20" "e-c-25" "e-a-5" "e-b-5" "e-d-5" ];
    }

    # e-c-6 - 10 edge nodes

    {
      name = "e-c-6";
      region = "ap-southeast-1";
      org = "IOHK";
      nodeId = 141;
      producers = [ "c-c-2" "e-c-1" "e-c-11" "e-c-16" "e-c-21" "e-a-6" "e-b-6" "e-d-6" ];
    }
    {
      name = "e-c-7";
      region = "ap-southeast-1";
      org = "IOHK";
      nodeId = 142;
      producers = [ "c-c-1" "e-c-2" "e-c-12" "e-c-17" "e-c-22" "e-a-7" "e-b-7" "e-d-7" ];
    }
    {
      name = "e-c-8";
      region = "ap-southeast-1";
      org = "IOHK";
      nodeId = 143;
      producers = [ "c-c-2" "e-c-3" "e-c-13" "e-c-18" "e-c-23" "e-a-8" "e-b-8" "e-d-8" ];
    }
    {
      name = "e-c-9";
      region = "ap-southeast-1";
      org = "IOHK";
      nodeId = 144;
      producers = [ "c-c-1" "e-c-4" "e-c-14" "e-c-19" "e-c-24" "e-a-9" "e-b-9" "e-d-9" ];
    }
    {
      name = "e-c-10";
      region = "ap-southeast-1";
      org = "IOHK";
      nodeId = 145;
      producers = [ "c-c-2" "e-c-5" "e-c-15" "e-c-20" "e-c-25" "e-a-10" "e-b-10" "e-d-10" ];
    }
    # e-c-11 - 15 edge nodes
    {
      name = "e-c-11";
      region = "ap-southeast-1";
      org = "IOHK";
      nodeId = 146;
      producers = [ "e-c-1" "e-c-6" "e-c-16" "e-c-21" "e-a-11" "e-b-11" "e-d-11" ];
    }
    {
      name = "e-c-12";
      region = "ap-southeast-1";
      org = "IOHK";
      nodeId = 147;
      producers = [ "e-c-2" "e-c-7" "e-c-17" "e-c-22" "e-a-12" "e-b-12" "e-d-12" ];
    }
    {
      name = "e-c-13";
      region = "ap-southeast-1";
      org = "IOHK";
      nodeId = 148;
      producers = [ "e-c-3" "e-c-8" "e-c-18" "e-c-23" "e-a-13" "e-b-13" "e-d-13" ];
    }
    {
      name = "e-c-14";
      region = "ap-southeast-1";
      org = "IOHK";
      nodeId = 149;
      producers = [ "e-c-4" "e-c-9" "e-c-19" "e-c-24" "e-a-14" "e-b-14" "e-d-14" ];
    }
    {
      name = "e-c-15";
      region = "ap-southeast-1";
      org = "IOHK";
      nodeId = 150;
      producers = [ "e-c-5" "e-c-10" "e-c-20" "e-c-25" "e-a-15" "e-b-15" "e-d-15" ];
    }
    # e-c-16 - 20 edge nodes
    {
      name = "e-c-16";
      region = "ap-southeast-1";
      org = "IOHK";
      nodeId = 151;
      producers = [ "e-c-1" "e-c-6" "e-c-11" "e-c-21" "e-a-16" "e-b-16" "e-d-16" ];
    }
    {
      name = "e-c-17";
      region = "ap-southeast-1";
      org = "IOHK";
      nodeId = 152;
      producers = [ "e-c-2" "e-c-7" "e-c-12" "e-c-22" "e-a-17" "e-b-17" "e-d-17" ];
    }
    {
      name = "e-c-18";
      region = "ap-southeast-1";
      org = "IOHK";
      nodeId = 153;
      producers = [ "e-c-3" "e-c-8" "e-c-13" "e-c-23" "e-a-18" "e-b-18" "e-d-18" ];
    }
    {
      name = "e-c-19";
      region = "ap-southeast-1";
      org = "IOHK";
      nodeId = 154;
      producers = [ "e-c-4" "e-c-9" "e-c-14" "e-c-24" "e-a-19" "e-b-19" "e-d-19" ];
    }
    {
      name = "e-c-20";
      region = "ap-southeast-1";
      org = "IOHK";
      nodeId = 155;
      producers = [ "e-c-5" "e-c-10" "e-c-15" "e-c-25" "e-a-20" "e-b-20" "e-d-20" ];
    }
    # e-c-21 - 25 edge nodes
    {
      name = "e-c-21";
      region = "ap-southeast-1";
      org = "IOHK";
      nodeId = 156;
      producers = [ "e-c-1" "e-c-6" "e-c-11" "e-c-16" "e-a-21" "e-b-21" "e-d-21" ];
    }
    {
      name = "e-c-22";
      region = "ap-southeast-1";
      org = "IOHK";
      nodeId = 157;
      producers = [ "e-c-2" "e-c-7" "e-c-12" "e-c-17" "e-a-22" "e-b-22" "e-d-22" ];
    }
    {
      name = "e-c-23";
      region = "ap-southeast-1";
      org = "IOHK";
      nodeId = 158;
      producers = [ "e-c-3" "e-c-8" "e-c-13" "e-c-18" "e-a-23" "e-b-23" "e-d-23" ];
    }
    {
      name = "e-c-24";
      region = "ap-southeast-1";
      org = "IOHK";
      nodeId = 159;
      producers = [ "e-c-4" "e-c-9" "e-c-14" "e-c-19" "e-a-24" "e-b-24" "e-d-24" ];
    }
    {
      name = "e-c-25";
      region = "ap-southeast-1";
      org = "IOHK";
      nodeId = 160;
      producers = [ "e-c-5" "e-c-10" "e-c-15" "e-c-20" "e-a-25" "e-b-25" "e-d-25" ];
    }

    # e-d-1 - 5 edge nodes

    {
      name = "e-d-1";
      region = "us-east-2";
      org = "IOHK";
      nodeId = 12;
      producers = [ "c-d-1" "e-d-6" "e-d-11" "e-d-16" "e-d-21" "e-a-1" "e-b-1" "e-c-1" "rel-e-1" ];
    }
    {
      name = "e-d-2";
      region = "us-east-2";
      org = "IOHK";
      nodeId = 31;
      producers = [ "c-d-1" "e-d-7" "e-d-12" "e-d-17" "e-d-22" "e-a-2" "e-b-2" "e-c-2" "rel-e-2" ];
    }
    {
      name = "e-d-3";
      region = "us-east-2";
      org = "IOHK";
      nodeId = 32;
      producers = [ "c-d-1" "e-d-8" "e-d-13" "e-d-18" "e-d-23" "e-a-3" "e-b-3" "e-c-3" "rel-e-3" ];
    }
    {
      name = "e-d-4";
      region = "us-east-2";
      org = "IOHK";
      nodeId = 33;
      producers = [ "c-d-1" "e-d-9" "e-d-14" "e-d-19" "e-d-24" "e-a-4" "e-b-4" "e-c-4" "rel-e-4" ];
    }
    {
      name = "e-d-5";
      region = "us-east-2";
      org = "IOHK";
      nodeId = 34;
      producers = [ "c-d-1" "e-d-10" "e-d-15" "e-d-20" "e-d-25" "e-a-5" "e-b-5" "e-c-5" "rel-e-5" ];
    }

    # e-d-6 - 10 edge nodes

    {
      name = "e-d-6";
      region = "us-east-2";
      org = "IOHK";
      nodeId = 161;
      producers = [ "c-d-1" "e-d-1" "e-d-11" "e-d-16" "e-d-21" "e-a-6" "e-b-6" "e-c-6" "rel-e-6" ];
    }
    {
      name = "e-d-7";
      region = "us-east-2";
      org = "IOHK";
      nodeId = 162;
      producers = [ "c-d-1" "e-d-2" "e-d-12" "e-d-17" "e-d-22" "e-a-7" "e-b-7" "e-c-7" "rel-e-7" ];
    }
    {
      name = "e-d-8";
      region = "us-east-2";
      org = "IOHK";
      nodeId = 163;
      producers = [ "c-d-1" "e-d-3" "e-d-13" "e-d-18" "e-d-23" "e-a-8" "e-b-8" "e-c-8" "rel-e-8" ];
    }
    {
      name = "e-d-9";
      region = "us-east-2";
      org = "IOHK";
      nodeId = 164;
      producers = [ "c-d-1" "e-d-4" "e-d-14" "e-d-19" "e-d-24" "e-a-9" "e-b-9" "e-c-9" "rel-e-9" ];
    }
    {
      name = "e-d-10";
      region = "us-east-2";
      org = "IOHK";
      nodeId = 165;
      producers = [ "c-d-1" "e-d-5" "e-d-15" "e-d-20" "e-d-25" "e-a-10" "e-b-10" "e-c-10" "rel-e-10" ];
    }
    # e-d-11 - 15 edge nodes
    {
      name = "e-d-11";
      region = "us-east-2";
      org = "IOHK";
      nodeId = 166;
      producers = [ "e-d-1" "e-d-6" "e-d-16" "e-d-21" "e-a-11" "e-b-11" "e-c-11" "rel-e-11" ];
    }
    {
      name = "e-d-12";
      region = "us-east-2";
      org = "IOHK";
      nodeId = 167;
      producers = [ "e-d-2" "e-d-7" "e-d-17" "e-d-22" "e-a-12" "e-b-12" "e-c-12" "rel-e-12" ];
    }
    {
      name = "e-d-13";
      region = "us-east-2";
      org = "IOHK";
      nodeId = 168;
      producers = [ "e-d-3" "e-d-8" "e-d-18" "e-d-23" "e-a-13" "e-b-13" "e-c-13" "rel-e-13" ];
    }
    {
      name = "e-d-14";
      region = "us-east-2";
      org = "IOHK";
      nodeId = 169;
      producers = [ "e-d-4" "e-d-9" "e-d-19" "e-d-24" "e-a-14" "e-b-14" "e-c-14" "rel-e-14" ];
    }
    {
      name = "e-d-15";
      region = "us-east-2";
      org = "IOHK";
      nodeId = 170;
      producers = [ "e-d-5" "e-d-10" "e-d-20" "e-d-25" "e-a-15" "e-b-15" "e-c-15" "rel-e-15" ];
    }
    # e-d-16 - 20 edge nodes
    {
      name = "e-d-16";
      region = "us-east-2";
      org = "IOHK";
      nodeId = 171;
      producers = [ "e-d-1" "e-d-6" "e-d-11" "e-d-21" "e-a-16" "e-b-16" "e-c-16" "rel-e-16" ];
    }
    {
      name = "e-d-17";
      region = "us-east-2";
      org = "IOHK";
      nodeId = 172;
      producers = [ "e-d-2" "e-d-7" "e-d-12" "e-d-22" "e-a-17" "e-b-17" "e-c-17" "rel-e-17" ];
    }
    {
      name = "e-d-18";
      region = "us-east-2";
      org = "IOHK";
      nodeId = 173;
      producers = [ "e-d-3" "e-d-8" "e-d-13" "e-d-23" "e-a-18" "e-b-18" "e-c-18" "rel-e-18" ];
    }
    {
      name = "e-d-19";
      region = "us-east-2";
      org = "IOHK";
      nodeId = 174;
      producers = [ "e-d-4" "e-d-9" "e-d-14" "e-d-24" "e-a-19" "e-b-19" "e-c-19" "rel-e-19" ];
    }
    {
      name = "e-d-20";
      region = "us-east-2";
      org = "IOHK";
      nodeId = 175;
      producers = [ "e-d-5" "e-d-10" "e-d-15" "e-d-25" "e-a-20" "e-b-20" "e-c-20" "rel-e-20" ];
    }

    # e-d-21 - 25 edge nodes
    {
      name = "e-d-21";
      region = "us-east-2";
      org = "IOHK";
      nodeId = 176;
      producers = [ "e-d-1" "e-d-6" "e-d-11" "e-d-16" "e-a-21" "e-b-21" "e-c-21" "rel-e-21" ];
    }
    {
      name = "e-d-22";
      region = "us-east-2";
      org = "IOHK";
      nodeId = 177;
      producers = [ "e-d-2" "e-d-7" "e-d-12" "e-d-17" "e-a-22" "e-b-22" "e-c-22" "rel-e-22" ];
    }
    {
      name = "e-d-23";
      region = "us-east-2";
      org = "IOHK";
      nodeId = 178;
      producers = [ "e-d-3" "e-d-8" "e-d-13" "e-d-18" "e-a-23" "e-b-23" "e-c-23" "rel-e-23" ];
    }
    {
      name = "e-d-24";
      region = "us-east-2";
      org = "IOHK";
      nodeId = 179;
      producers = [ "e-d-4" "e-d-9" "e-d-14" "e-d-19" "e-a-24" "e-b-24" "e-c-24" "rel-e-24" ];
    }
    {
      name = "e-d-25";
      region = "us-east-2";
      org = "IOHK";
      nodeId = 180;
      producers = [ "e-d-5" "e-d-10" "e-d-15" "e-d-20" "e-a-25" "e-b-25" "e-c-25" "rel-e-25" ];
    }
  ];

in {

  # Comment the following line after hard fork to remove dr nodes from relay role
  #privateRelayNodes = recoveryCoreNodes;

  # Remove comment after hard fork and redeploy dr nodes
  coreNodes = oldCoreNodes ++ recoveryCoreNodes;

  relayNodes = oldRelayNodes ++ londonRelayNodes ++ californiaRelayNodes;

  legacyRelayNodes = [];
  byronProxies = [];
  legacyCoreNodes = [];
}
