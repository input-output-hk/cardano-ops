{ callPackage, callPackages, varnish60, varnish61, varnish62, varnish63, varnish64, varnish65 }:

{
  varnish60Packages = {
    varnish = varnish60;
    digest  = callPackage ./digest.nix   { varnish = varnish60; };
    dynamic = callPackage ./dynamic.nix  { varnish = varnish60; };
    modules = (callPackages ./modules.nix { varnish = varnish60; }).modules60;
  };
  varnish61Packages = {
    varnish = varnish61;
    modules = (callPackages ./modules.nix { varnish = varnish61; }).modules61;
  };
  varnish62Packages = {
    varnish = varnish62;
    modules = (callPackages ./modules.nix { varnish = varnish62; }).modules62;
  };
  varnish63Packages = {
    varnish = varnish63;
    modules = (callPackages ./modules.nix { varnish = varnish63; }).modules63;
  };
  varnish64Packages = {
    varnish = varnish64;
    modules = (callPackages ./modules.nix { varnish = varnish64; }).modules64;
  };
  varnish65Packages = {
    varnish = varnish65;
    modules = (callPackages ./modules.nix { varnish = varnish65; }).modules65;
  };
}
