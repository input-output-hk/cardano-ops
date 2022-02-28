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

  config = {
    services.monitoring-exporters.logging = false;
  };

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
        isCardanoDensePool = boolOption;
        isCardanoLegacyCore = boolOption;
        isCardanoLegacyRelay = boolOption;
        isCardanoRelay = boolOption;
        isSnapshots = boolOption;
        isCustom = boolOption;
        isExplorer = boolOption;
        isExplorerBackend = boolOption;
        isFaucet = boolOption;
        isMonitor = boolOption;
        isMetadata = boolOption;
        isPublicSsh = boolOption;
      };
    };
  };
}
