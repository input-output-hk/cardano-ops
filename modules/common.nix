pkgs:
with pkgs;
let
  boolOption = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };
in {
  imports = [
    iohk-ops-lib.modules.common
  ];

  options = {
    node = {
      coreIndex = lib.mkOption {
        type = lib.types.int;
      };
      nodeId = lib.mkOption {
        type = lib.types.int;
      };
      roles = {
        isByronProxy = boolOption;
        isCardanoCore = boolOption;
        isCardanoLegacyCore = boolOption;
        isCardanoLegacyRelay = boolOption;
        isCardanoRelay = boolOption;
        isExplorer = boolOption;
        isFaucet = boolOption;
        isMonitor = boolOption;
        isMetadataServer = boolOption;
        isSmash = boolOption;
      };
    };
  };
}
