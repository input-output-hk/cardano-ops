sourcePaths:
  # overlays from ops-lib (include ops-lib sourcePaths):
  (import sourcePaths.ops-lib {}).overlays
  # our own overlays:
  ++ map import (import ./overlay-list.nix)
  # merge upstream sources with our own:
  ++ [( _: super: { sourcePaths = if (super ? sourcePaths) then super.sourcePaths // sourcePaths else sourcePaths ;})]
