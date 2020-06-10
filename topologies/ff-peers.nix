# List of peers included in our relays topology config,
# evenly split across all IOHK FF relays.
# Pull-requests against this file will be merged and deployed once a day.
[
  {
    operator = "disassembler";
    addr = "prophet.samleathers.com";
    port = 3001;
    # valency = 1; (default)
  }
  {
    operator = "SkyLightPool";
    addr = "relay1.oqulent.com";
    port = 3007;
    valency = 1;
  }
  {
    operator = "SkyLightPool";
    addr = "relay2.oqulent.com";
    port = 3008;
    valency = 1;
  }
]
