pkgs: with pkgs.lib;
let condImport = name: file: optionalAttrs (builtins.pathExists file) {
  "${name}" = import file;
};
in {
  additionalPeers = [];
  relaysExcludeList = [];
  poolsExcludeList = [];
} // condImport "graylogCreds" ./graylog-creds.nix
  // condImport "grafanaCreds" ./grafana-creds.nix
  // condImport "pagerDuty" ./pager-duty.nix
  // condImport "deadMansSnitch" ./dead-mans-snitch.nix
  // condImport "oauth" ./oauth.nix
  // (condImport "static" ./static.nix).static or {}
