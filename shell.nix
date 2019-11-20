with import ./nix {};
mkShell {
  buildInputs = [ niv nixops nix nix-prefetch-scripts git curl cacert ];

  passthru = {
    gen-graylog-creds = iohk-ops-lib.scripts.gen-graylog-creds { staticPath = ./static; };
  };
}
