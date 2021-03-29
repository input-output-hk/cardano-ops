{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "oauth2-proxy-multi-providers";
  version = "7.0.1";

  src = fetchFromGitHub {
    repo = "oauth2-proxy";
    owner = "nielsen-oss";
    sha256 = "sha256-FjWANICP2Br3ra6lNz6you8jhrrKrADVoYdq4KAai2Y=";
    rev = "b112c5ff79dc0ee4bd87fd94a4b3555ddb6985cc";
  };

  doCheck = false;

  vendorSha256 = "sha256-iarRUGrWoA2ArXJCi+L6j4IQ+43htSEUhX7ivXelpLI=";

  # Taken from https://github.com/oauth2-proxy/oauth2-proxy/blob/master/Makefile
  buildFlagsArray = ("-ldflags=-X main.VERSION=${version}");

  meta = with lib; {
    description = "A reverse proxy that provides authentication with Google, Github, or other providers";
    homepage = "https://github.com/oauth2-proxy/oauth2-proxy/";
    license = licenses.mit;
    maintainers = with maintainers; [ yorickvp knl ];
  };
}
