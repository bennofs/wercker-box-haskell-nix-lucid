let
  pkgs = import <nixpkgs> { config = {}; };
  inherit (pkgs) haskellngPackages lib writeScript stdenv;
  sources = {
    ghc = rec {
      src = pkgs.fetchurl {
        url = "https://www.haskell.org/ghc/dist/${version}/ghc-${version}-i386-unknown-linux-centos65.tar.bz2";
        sha256 = "082228lv4zf3jqxkibmjw3n1g54h5802r2jqa662afl0inm73v9g";
      };
      version = "7.8.4";
    };

    debs = rec {
      srcs = map pkgs.fetchurl (import ./debs.nix);
      src = pkgs.stdenv.mkDerivation {
        name = "debs";
        phases = ["buildPhase"];
        buildPhase = with pkgs.lib; ''
          mkdir $out;
          ${concatStringsSep "\n" (map (x: "cp ${x} $out") srcs)}
        '';
      };
    };
  };

  base-rootfs = with pkgs; with lib; stdenv.mkDerivation {
    name = "sc-build-rootfs";
    src = fetchurl {
      url = "http://download.openvz.org/template/precreated/ubuntu-10.04-x86.tar.gz";
      sha256 = "1zpir2a4w1m5ar82qc3zf6sj7xp6r883i76f8cl9xgzwc2nj4ds9";
    };
    buildInputs = [ proot ];
    phases = [ "unpackPhase" "buildPhase" ];

    binds = concatStringsSep " " (mapAttrsToList (n: v: "-b " + v.src + ":/sources/" + n) sources);
    script = ''
      export PATH=/bin:/sbin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin
      ln -s /lib/libncurses.so.5 /usr/lib/libtinfo.so.5
      ln -s /usr/lib/libtinfo.so.5 /usr/lib/libtinfo.so

      echo "-- Installing dependencies ..." && dpkg -i /sources/debs/${"*"}
      echo "-- Installing ghc ..." && cd /sources && tar -xf /sources/ghc && cd ghc-${sources.ghc.version} && ./configure && make install
      cd /sources && rm -rf ghc-${sources.ghc.version}
    '';

    unpackPhase = ''
      mkdir -p $out
      cd $out
      tar --exclude="./dev/*" --exclude="./lib/udev/devices/*" -xf $src
      ln -s /proc/self/fd/ $out/lib/udev/devices/fd
      ln -s /proc/kcore $out/lib/udev/devices/core
      ln -s fd/0 $out/lib/udev/devices/stdin
      ln -s fd/1 $out/lib/udev/devices/stdout
      ln -s fd/2 $out/lib/udev/devices/stderr
    '';

    buildPhase = ''
      echo "$script" > $out/provision
      proot -w / $binds -b /proc -b /dev -0 -r $out /usr/bin/env -i /bin/bash /provision
    '';
  };

  buildInChroot = deriv: lib.overrideDerivation deriv (old: {
    args = ["-e"  (pkgs.writeScript "builder" '' exec \
      ${pkgs.proot}/bin/proot -b /proc -b /nix -b /dev -b /tmp -0 -r ${base-rootfs} \
        /usr/bin/env LANG=C /bin/bash --rcfile /etc/environment \
          ${lib.concatStringsSep " " (map (x: "\"" + x + "\"") old.args)}
      '')
    ];
  });

  ccWrapperPath =
    if builtins.pathExists <nixpkgs/pkgs/build-support/cc-wrapper>
    then <nixpkgs/pkgs/build-support/cc-wrapper>
    else <nixpkgs/pkgs/build-support/gcc-wrapper>;

  chrootGCC = lib.overrideDerivation
    (buildInChroot (import ccWrapperPath {
      nativeTools = true;
      nativeLibc = true;
      nativePrefix = "/usr";
      shell = "/bin/bash";
      name = "gcc-base-rootfs";
      inherit stdenv;
    })) (old: {
      buildCommand = ''
        ${old.buildCommand}
        ln -s /usr/bin/ar $out/bin/ar
      '';
    });

  chrootStdenv =
    let env = stdenv.override (old: {
      preHook = ''
        ${old.preHook or ""}
        export NIX_ENFORCE_PURITY=0
      '';
      cc = chrootGCC;
      allowedRequisites = null;
    }); in env // {
      mkDerivation = attrs: buildInChroot (env.mkDerivation attrs);
    };

  chrootGHC = {
    inherit (sources.ghc) version;
    meta.platforms = lib.platforms.linux;
    name = "ghc-${sources.ghc.version}";
    outPath = "/usr/local";
  };

  chrootCabalBuilder =
   import <nixpkgs/pkgs/development/haskell-modules/generic-builder.nix> {
    inherit (pkgs) fetchurl glibcLocales coreutils gnugrep gnused;
    inherit (haskellngPackages) jailbreak-cabal hscolour cpphs;
    ghc = chrootGHC;
    stdenv = chrootStdenv;
    pkgconfig = "/usr";
  };

  cabalDefaults = {
    doCheck = false;
    doHaddock = false;
    enableLibraryProfiling = false;
  };

  chrootHaskellPackages = haskellngPackages.override (old: {
    stdenv = chrootStdenv;
    overrides = self: super: (old.overrides or (_: _: {})) self super // {
      mkDerivation = args: chrootCabalBuilder (cabalDefaults // args );
      ghc = chrootGHC;
    };
    pkgs = let result = pkgs // {
      callPackage = pkgs.callPackageWithScope result;

      # provided by ubuntu base system
      zlib = null;
      openssl = null;
    }; in result;
  });

in chrootHaskellPackages
