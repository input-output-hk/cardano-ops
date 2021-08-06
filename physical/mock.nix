{
  node-0 = { config, lib, pkgs, ... }: {
    config = {
      boot.kernelModules = [];
      networking = {
        extraHosts = ''
          1.1.1.1 node-0 node-0-ip
          1.1.1.1 node-1 node-1-ip
          1.1.1.1 node-2 node-2-ip
          1.1.1.1 explorer explorer-ip
        '';
        firewall.trustedInterfaces = [];
        privateIPv4 = "1.1.1.1";
        publicIPv4 = "1.1.1.1";
        vpnPublicKey = "";
      };
      services.openssh.knownHosts = {
        explorer = { hostNames = ["explorer"]; publicKey = ""; };
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
  node-1 = { config, lib, pkgs, ... }: {
    config = {
      boot.kernelModules = [];
      networking = {
        extraHosts = ''
          1.1.1.1 node-0 node-0-ip
          1.1.1.1 node-1 node-1-ip
          1.1.1.1 node-2 node-2-ip
          1.1.1.1 explorer explorer-ip
        '';
        firewall.trustedInterfaces = [];
        privateIPv4 = "1.1.1.1";
        publicIPv4 = "1.1.1.1";
        vpnPublicKey = "";
      };
      services.openssh.knownHosts = {
        explorer = { hostNames = ["explorer"]; publicKey = ""; };
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
  node-2 = { config, lib, pkgs, ... }: {
    config = {
      boot.kernelModules = [];
      networking = {
        extraHosts = ''
          1.1.1.1 node-0 node-0-ip
          1.1.1.1 node-1 node-1-ip
          1.1.1.1 node-2 node-2-ip
          1.1.1.1 explorer explorer-ip
        '';
        firewall.trustedInterfaces = [];
        privateIPv4 = "1.1.1.1";
        publicIPv4 = "1.1.1.1";
        vpnPublicKey = "";
      };
      services.openssh.knownHosts = {
        explorer = { hostNames = ["explorer"]; publicKey = ""; };
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
          1.1.1.1 node-0 node-0-ip
          1.1.1.1 node-1 node-1-ip
          1.1.1.1 node-2 node-2-ip
          1.1.1.1 explorer explorer-ip
        '';
        firewall.trustedInterfaces = [];
        privateIPv4 = "1.1.1.1";
        publicIPv4 = "1.1.1.1";
        vpnPublicKey = "";
      };
      services.openssh.knownHosts = {
        explorer = { hostNames = ["explorer"]; publicKey = ""; };
      };
      system.stateVersion = ( lib.mkDefault "21.09" );
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
    };
    elasticIPs = {
      "node-0-ip" = { config, lib, pkgs, ... }: {
        config = {};
        imports = [ { address = "1.1.1.1"; } ];
      };
      "node-1-ip" = { config, lib, pkgs, ... }: {
        config = {};
        imports = [ { address = "1.1.1.1"; } ];
      };
      "node-2-ip" = { config, lib, pkgs, ... }: {
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
