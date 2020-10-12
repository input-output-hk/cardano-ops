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
        isCardanoLegacyCore = boolOption;
        isCardanoLegacyRelay = boolOption;
        isCardanoCore = boolOption;
        isCardanoRelay = boolOption;
        isCardanoDensePool = boolOption;
        isByronProxy = boolOption;
        isMonitor = boolOption;
        isExplorer = boolOption;
        isFaucet = boolOption;
      };
    };
  };
}
