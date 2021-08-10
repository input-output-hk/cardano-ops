{ lib, stdenv, fetchurl, fetchpatch, pcre, libxslt, groff, ncurses, pkg-config, readline, libedit
, python3, makeWrapper, jemalloc }:

let
  common = { version, sha256, extraNativeBuildInputs ? [], patches ? [] }:
    stdenv.mkDerivation rec {
      pname = "varnish";
      inherit version patches;

      src = fetchurl {
        url = "https://varnish-cache.org/_downloads/${pname}-${version}.tgz";
        inherit sha256;
      };

      passthru.python = python3;

      nativeBuildInputs = with python3.pkgs; [ pkg-config docutils sphinx ];
      buildInputs = [
        pcre libxslt groff ncurses readline libedit makeWrapper python3 jemalloc
      ];

      #Use external jemmaloc: https://github.com/varnishcache/varnish-cache/issues/3511
      buildFlags = [ "localstatedir=/var/spool" "JEMALLOC_LDADD=${jemalloc}/lib/libjemalloc.so" ];

      postInstall = ''
        wrapProgram "$out/sbin/varnishd" --prefix PATH : "${lib.makeBinPath [ stdenv.cc ]}"
      '';

      # https://github.com/varnishcache/varnish-cache/issues/1875
      NIX_CFLAGS_COMPILE = lib.optionalString stdenv.isi686 "-fexcess-precision=standard";

      outputs = [ "out" "dev" "man" ];

      meta = with lib; {
        description = "Web application accelerator also known as a caching HTTP reverse proxy";
        homepage = "https://www.varnish-cache.org";
        license = licenses.bsd2;
        maintainers = with maintainers; [ fpletz ];
        platforms = platforms.unix;
      };
    };
in
{
  varnish60 = common {
    version = "6.0.7";
    sha256 = "0njs6xpc30nc4chjdm4d4g63bigbxhi4dc46f4az3qcz51r8zl2a";
  };
  varnish61 = common {
    version = "6.1.1";
    sha256 = "0gf9hzzrr1lndbbqi8cwlfasi7l517cy3nbgna88i78lm247rvp0";
    patches = [
      # [PATCH] Avoid printing %s,NULL in case of errors we do not expect.
      (fetchpatch {
        url = https://github.com/varnishcache/varnish-cache/commit/7119d790b590e7fb560ad602cedfda5185c7e841.patch;
        sha256 = "19ql4d5124jqdpapnwc1w10ph9kabhf9hfgwkakfnni3lca4nsyv";
      })
    ];
  };
  varnish62 = common {
    version = "6.2.3";
    sha256 = "02b6pqh5j1d4n362n42q42bfjzjrngd6x49b13q7wzsy6igd1jsy";
  };
  varnish63 = common {
    version = "6.3.2";
    sha256 = "1f5ahzdh3am6fij5jhiybv3knwl11rhc5r3ig1ybzw55ai7788q8";
  };
  varnish64 = common {
    version = "6.4.0";
    sha256 = "1hkn98vbxk7rc1sd08367qn6rcv8wkxgwbmm1x46y50vi0nvldpn";
  };
  varnish65 = common {
    version = "6.5.1";
    sha256 = "1dfdswri6lkfk6kml3szvffm91y49pajgqy1k5y26llqixl4r5hi";
  };
}
