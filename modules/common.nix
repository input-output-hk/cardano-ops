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
      isCardanoLegacyCore = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      isCardanoLegacyRelay = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
    };
  };
}
