{
  a = { config, lib, pkgs, ... }: {
    config = {
      boot.kernelModules = [];
      networking = {
        extraHosts = ''
          1.1.1.1 a a-unencrypted
          1.1.1.1 a-encrypted
          1.1.1.1 a-ip a-ip-unencrypted
          1.1.1.1 b b-unencrypted
          1.1.1.1 b-ip b-ip-unencrypted
          1.1.1.1 c c-unencrypted
          1.1.1.1 c-ip c-ip-unencrypted
          1.1.1.1 explorer explorer-unencrypted
          1.1.1.1 explorer-ip explorer-ip-unencrypted
        '';
        firewall.trustedInterfaces = [];
        privateIPv4 = "1.1.1.1";
        publicIPv4 = "1.1.1.1";
        vpnPublicKey = "";
      };
      services.openssh.knownHosts = {
        a = {
          hostNames = [ "a-unencrypted" "a-encrypted" "a" ];
          publicKey = "";
        };
        b = {
          hostNames = [ "b-unencrypted" "b-encrypted" "b" ];
          publicKey = "";
        };
        c = {
          hostNames = [ "c-unencrypted" "c-encrypted" "c" ];
          publicKey = "";
        };
        explorer = {
          hostNames = [
            "explorer-unencrypted"
            "explorer-encrypted"
            "explorer"
          ];
          publicKey = "";
        };
      };
      system.stateVersion = ( lib.mkDefault "19.09" );
    };
    imports = [
      {
        deployment.ec2 = {
          blockDeviceMapping = {};
          instanceId = "";
        };
        ec2.hvm = true;
        imports = [ <nixpkgs/nixos/modules/virtualisation/amazon-image.nix> ];
      }
    ];
  };
  b = { config, lib, pkgs, ... }: {
    config = {
      boot.kernelModules = [];
      networking = {
        extraHosts = ''
          1.1.1.1 a a-unencrypted
          1.1.1.1 a-ip a-ip-unencrypted
          1.1.1.1 b b-unencrypted
          1.1.1.1 b-encrypted
          1.1.1.1 b-ip b-ip-unencrypted
          1.1.1.1 c c-unencrypted
          1.1.1.1 c-ip c-ip-unencrypted
          1.1.1.1 explorer explorer-unencrypted
          1.1.1.1 explorer-ip explorer-ip-unencrypted
        '';
        firewall.trustedInterfaces = [];
        privateIPv4 = "1.1.1.1";
        publicIPv4 = "1.1.1.1";
        vpnPublicKey = "";
      };
      services.openssh.knownHosts = {
        a = {
          hostNames = [ "a-unencrypted" "a-encrypted" "a" ];
          publicKey = "";
        };
        b = {
          hostNames = [ "b-unencrypted" "b-encrypted" "b" ];
          publicKey = "";
        };
        c = {
          hostNames = [ "c-unencrypted" "c-encrypted" "c" ];
          publicKey = "";
        };
        explorer = {
          hostNames = [
            "explorer-unencrypted"
            "explorer-encrypted"
            "explorer"
          ];
          publicKey = "";
        };
      };
      system.stateVersion = ( lib.mkDefault "19.09" );
    };
    imports = [
      {
        deployment.ec2 = {
          blockDeviceMapping = {};
          instanceId = "";
        };
        ec2.hvm = true;
        imports = [ <nixpkgs/nixos/modules/virtualisation/amazon-image.nix> ];
      }
    ];
  };
  c = { config, lib, pkgs, ... }: {
    config = {
      boot.kernelModules = [];
      networking = {
        extraHosts = ''
          1.1.1.1 a a-unencrypted
          1.1.1.1 a-ip a-ip-unencrypted
          1.1.1.1 b b-unencrypted
          1.1.1.1 b-ip b-ip-unencrypted
          1.1.1.1 c c-unencrypted
          1.1.1.1 c-encrypted
          1.1.1.1 c-ip c-ip-unencrypted
          1.1.1.1 explorer explorer-unencrypted
          1.1.1.1 explorer-ip explorer-ip-unencrypted
        '';
        firewall.trustedInterfaces = [];
        privateIPv4 = "1.1.1.1";
        publicIPv4 = "1.1.1.1";
        vpnPublicKey = "";
      };
      services.openssh.knownHosts = {
        a = {
          hostNames = [ "a-unencrypted" "a-encrypted" "a" ];
          publicKey = "";
        };
        b = {
          hostNames = [ "b-unencrypted" "b-encrypted" "b" ];
          publicKey = "";
        };
        c = {
          hostNames = [ "c-unencrypted" "c-encrypted" "c" ];
          publicKey = "";
        };
        explorer = {
          hostNames = [
            "explorer-unencrypted"
            "explorer-encrypted"
            "explorer"
          ];
          publicKey = "";
        };
      };
      system.stateVersion = ( lib.mkDefault "19.09" );
    };
    imports = [
      {
        deployment.ec2 = {
          blockDeviceMapping = {};
          instanceId = "";
        };
        ec2.hvm = true;
        imports = [ <nixpkgs/nixos/modules/virtualisation/amazon-image.nix> ];
      }
    ];
  };
  explorer = { config, lib, pkgs, ... }: {
    config = {
      boot.kernelModules = [];
      networking = {
        extraHosts = ''
          1.1.1.1 a a-unencrypted
          1.1.1.1 a-ip a-ip-unencrypted
          1.1.1.1 b b-unencrypted
          1.1.1.1 b-ip b-ip-unencrypted
          1.1.1.1 c c-unencrypted
          1.1.1.1 c-ip c-ip-unencrypted
          1.1.1.1 explorer explorer-unencrypted
          1.1.1.1 explorer-encrypted
          1.1.1.1 explorer-ip explorer-ip-unencrypted
        '';
        firewall.trustedInterfaces = [];
        privateIPv4 = "1.1.1.1";
        publicIPv4 = "1.1.1.1";
        vpnPublicKey = "";
      };
      services.openssh.knownHosts = {
        a = {
          hostNames = [ "a-unencrypted" "a-encrypted" "a" ];
          publicKey = "";
        };
        b = {
          hostNames = [ "b-unencrypted" "b-encrypted" "b" ];
          publicKey = "";
        };
        c = {
          hostNames = [ "c-unencrypted" "c-encrypted" "c" ];
          publicKey = "";
        };
        explorer = {
          hostNames = [
            "explorer-unencrypted"
            "explorer-encrypted"
            "explorer"
          ];
          publicKey = "";
        };
      };
      system.stateVersion = ( lib.mkDefault "19.09" );
    };
    imports = [
      {
        deployment.ec2 = {
          blockDeviceMapping = {};
          instanceId = "";
        };
        ec2.hvm = true;
        imports = [ <nixpkgs/nixos/modules/virtualisation/amazon-image.nix> ];
      }
    ];
  };
  resources = {
    ec2SecurityGroups = {
      "allow-deployer-ssh-ap-southeast-2-IOHK" = { config, lib, pkgs, ... }: {
        config = {};
        imports = [ { groupId = ""; } ];
      };
      "allow-deployer-ssh-eu-central-1-IOHK" = { config, lib, pkgs, ... }: {
        config = {};
        imports = [ { groupId = ""; } ];
      };
      "allow-deployer-ssh-us-east-1-IOHK" = { config, lib, pkgs, ... }: {
        config = {};
        imports = [ { groupId = ""; } ];
      };
      "allow-public-www-https-eu-central-1-IOHK" = { config, lib, pkgs, ... }: {
        config = {};
        imports = [ { groupId = ""; } ];
      };
      "allow-to-cardano-ap-southeast-2-IOHK" = { config, lib, pkgs, ... }: {
        config = {};
        imports = [ { groupId = ""; } ];
      };
      "allow-to-cardano-eu-central-1-IOHK" = { config, lib, pkgs, ... }: {
        config = {};
        imports = [ { groupId = ""; } ];
      };
      "allow-to-cardano-us-east-1-IOHK" = { config, lib, pkgs, ... }: {
        config = {};
        imports = [ { groupId = ""; } ];
      };
    };
    elasticIPs = {
      "a-ip" = { config, lib, pkgs, ... }: {
        config = {};
        imports = [ { address = "1.1.1.1"; } ];
      };
      "b-ip" = { config, lib, pkgs, ... }: {
        config = {};
        imports = [ { address = "1.1.1.1"; } ];
      };
      "c-ip" = { config, lib, pkgs, ... }: {
        config = {};
        imports = [ { address = "1.1.1.1"; } ];
      };
      "explorer-ip" = { config, lib, pkgs, ... }: {
        config = {};
        imports = [ { address = "1.1.1.1"; } ];
      };
    };
  };
}
