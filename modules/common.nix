with (import ../nix {});
{ ... }: {
  imports = [
    iohk-ops-lib.modules.common
  ];

  options = {
    node = {
      org = lib.mkOption {
        type = lib.types.enum [ "IOHK" "Emurgo" "CF" ];
        default = "IOHK";
      };
      coreIndex = lib.mkOption {
        type = lib.types.int;
      };
      roles = {
        isCardanoLegacyCore = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        isCardanoLegacyRelay = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        isCardanoCore = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        isCardanoRelay = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        isByronProxy = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        isMonitor = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        isExplorer = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
      };
    };
  };
}
