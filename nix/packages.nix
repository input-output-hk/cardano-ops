self: super: {
  pp = v: __trace (__toJSON v) v;
  leftPad = number: width: self.lib.fixedWidthString width "0" (toString number);
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
}
