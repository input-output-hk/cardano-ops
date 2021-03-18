{ lib, buildGoModule, fetchFromGitHub, makeWrapper, varnish }:

buildGoModule rec {
  pname = "prometheus_varnish_exporter";
  version = "unstable-2021-01-27";

  src = fetchFromGitHub {
    owner = "jonnenauha";
    repo = "prometheus_varnish_exporter";
    rev = "86fc1b025dd41eaf43a583a262daec6cad69b561";
    sha256 = "1gnil3zs6x1bg68ldykbi0nisiaiz28wqp1j0hfqz3cvhwn56r3s";
  };

  modSha256 = "1hhs6hr99qd4q9wghyn3jjsihv7m5iq78464dng54xl8x3k0n0w7";

  vendorSha256 = "1cslg29l9mmyhpdz14ca9m18iaz4hhznplz8fmi3wa3l8r7ih751";

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    wrapProgram $out/bin/prometheus_varnish_exporter \
      --prefix PATH : "${varnish}/bin"
  '';

  doCheck = true;

  meta = {
    homepage = "https://github.com/jonnenauha/prometheus_varnish_exporter";
    description = "Varnish exporter for Prometheus";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ MostAwesomeDude willibutz ];
  };
}
