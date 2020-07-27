{
  deadMansSnitch = import ./dead-mans-snitch.nix;
  grafanaCreds = import ./grafana-creds.nix;
  graylogCreds = import ./graylog-creds.nix;
  oauth = import ./oauth.nix;
  pagerDuty = import ./pager-duty.nix;
  additionalPeers = [];
} // (if (builtins.pathExists ./static.nix)
  then (import ./static.nix)
  else {})
