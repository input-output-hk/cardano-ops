{ lib, stdenv, fetchFromGitHub, autoreconfHook, pkg-config, varnish, docutils, removeReferencesTo }:
let
  common = { version, sha256, extraNativeBuildInputs ? [] }:
    stdenv.mkDerivation rec {
      pname = "${varnish.name}-modules";
      inherit version;

      src = fetchFromGitHub {
        owner = "varnish";
        repo = "varnish-modules";
        rev = version;
        inherit sha256;
      };

      nativeBuildInputs = [
        autoreconfHook
        docutils
        pkg-config
        removeReferencesTo
        varnish.python  # use same python version as varnish server
      ];

      buildInputs = [ varnish ];

      postPatch = ''
        substituteInPlace bootstrap   --replace "''${dataroot}/aclocal"                  "${varnish.dev}/share/aclocal"
        substituteInPlace Makefile.am --replace "''${LIBVARNISHAPI_DATAROOTDIR}/aclocal" "${varnish.dev}/share/aclocal"
      '';

      postInstall = "find $out -type f -exec remove-references-to -t ${varnish.dev} '{}' +"; # varnish.dev captured only as __FILE__ in assert messages

      meta = with lib; {
        description = "Collection of Varnish Cache modules (vmods) by Varnish Software";
        homepage = "https://github.com/varnish/varnish-modules";
        inherit (varnish.meta) license platforms maintainers;
      };
    };
in
{
  modules60 = common {
    version = "0.15.1";
    sha256 = "1lwgjhgr5yw0d17kbqwlaj5pkn70wvaqqjpa1i0n459nx5cf5pqj";
  };
  modules61 = common {
    version = "0.15.2";
    sha256 = "18g1s3dpl62bcgqsqd538y2dkfji2pdrl2vdipj0mvc9ixbhc8yr";
  };
  modules62 = common {
    version = "0.15.3";
    sha256 = "0b6vvx3sfm5rd38dn32pxbzdvx2nvjsr61fywz1qbx25y3q5mczh";
  };
  modules63 = common {
    version = "0.15.4";
    sha256 = "0s6ylfsifvk6dq6vvnbfy14jvz8lnfynlsxi8lgixls3j2h7rnmw";
  };
  modules64 = common {
    version = "0.16.0";
    sha256 = "01ha5fdlpp03cjcxy1zpibn3gn46j0viz83fan1qvhrpnymmbm8f";
  };
  modules65 = common {
    version = "0.17.0";
    sha256 = "0zg8y2sgkygdani70zp9rbx278431fmssj26d47c5qsiw939i519";
  };
}
