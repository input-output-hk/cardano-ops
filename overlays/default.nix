sources:
  # overlays from ops-lib (include ops-lib sources):
  (import sources.ops-lib {}).overlays
  # our own overlays:
  ++ map import (import ./overlay-list.nix)
  # merge upstream sources with our own:
  ++ [( _: super: { sources = if (super ? sources) then super.sources // sources else sources ;})]
