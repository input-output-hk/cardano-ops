self: super: {

  pp = v: __trace (__toJSON v) v;
  leftPad = number: width: self.lib.fixedWidthString width "0" (toString number);
  getPublicIp = resources: nodes: nodeName:
    resources.elasticIPs."${nodeName}-ip".address or
    (let
      publicIp = nodes.${nodeName}.config.networking.publicIPv4;
    in
      if (nodes.${nodeName}.options.networking.publicIPv4.isDefined && publicIp != null) then publicIp
      else (builtins.trace "No public IP found for node: ${nodeName}" "")
    );
  getStaticRouteIp = resources: nodes: nodeName: resources.elasticIPs."${nodeName}-ip".address
    or (let
      publicIp = nodes.${nodeName}.config.networking.publicIPv4;
      privateIp = nodes.${nodeName}.config.networking.privateIPv4;
    in
      if (nodes.${nodeName}.options.networking.publicIPv4.isDefined && publicIp != null) then publicIp
      else if (nodes.${nodeName}.options.networking.privateIPv4.isDefined && privateIp != null) then privateIp
      else (builtins.trace "No suitable ip found for node: ${nodeName}" "")
    );

  getListenIp = node:
    let ip = node.config.networking.privateIPv4;
    in if (node.options.networking.privateIPv4.isDefined && ip != null) then ip else "0.0.0.0";

  # this function import all nix files of the given directory,
  # returned in a attribute set indexed by name (with .nix suffix removed)
  # Furthermore, if the imported file is a function with an opaque argument,
  # that argument is assumed to be pkgs and is applied.
  # This allows to easliy inject a lazy pkgs to functions that return modules:
  # using pkgs in modules arg as limitation; due to modules args being strictly evaluated
  # they cannot be used for shaping the module structure (like in imports), otherwise
  # "infinite recursions" occurs.
  # This can greatly improve nixops eval perf /memory usage
  # when pkgs is the same for all machines (common case).
  importWithPkgs = with self.lib; dir:
    mapAttrs' (n: v:
      let l = stringLength n;
        nix = import (dir + "/${n}");
      in nameValuePair
        (substring 0 (l - 4) n)
        (if (isFunction nix && functionArgs nix == {})
          then nix self
          else nix)
    ) (filterAttrs (n: v:
        let l = stringLength n;
        in v == "regular" && (substring (l - 4) l n) == ".nix")
        (builtins.readDir dir));

  aws-affinity-indexes = self.runCommand "aws-affinity-indexes" {
    nativeBuildInputs = with self; [ csvkit jq ];
  } ''
    mkdir -p $out
    csvjson -d ";" -I --blanks -H ${self.sourcePaths.aws-datacenters}/output/countries.index | jq 'map( { (.a): .c } ) | add' \
      > $out/countries-index.json
    csvjson -d ";" -I --blanks -H ${self.sourcePaths.aws-datacenters}/output/usa.index | jq 'map( { (.b): .c } ) | add' \
      > $out/usa-index.json
    jq -s 'add' $out/countries-index.json $out/usa-index.json > $out/state-index.json
  '';

  topology-lib = import ./topology-lib.nix self;

}
