self: super: {
  globals = {
    static = import ./static;

    domain = "";

    systemStart = 0;

    applicationMonitoringPortsFor = name: node: [ ];

    configurationKey = "mainnet_staging_short_epoch_full";
  };
}
