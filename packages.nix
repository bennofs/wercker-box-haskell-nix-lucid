let
  pkgs = import <nixpkgs> { config = {}; };
  haskellPackages = import ./lucid-haskell-packages.nix;
  deriv = pkgs.stdenv.mkDerivation {
    name = "stackage-packages";
    buildCommand = ''
      echo "{" >> $out
      tr "\n" "," < ${./packages} >> $out
      echo "}: { inherit " >> $out
      cat ${./packages} >> $out
      echo "; }" >> $out
    '';
  };
  stackagePackages = with builtins; filter (x: !isFunction x && x != null) (attrValues (haskellPackages.callPackage (import deriv) {}));
  extraPackages = with haskellPackages; [ storable-record ];
  overrideCabal = drv: f: if drv == null then drv else drv.override (args: args // {
    mkDerivation = drv: args.mkDerivation (drv // f drv);
  });
  checkExtraDeps = with builtins; d: overrideCabal d (old: {
    passthru = {
      enabled = [] == filter (x: x != null) (old.extraLibraries or [] ++ old.pkgconfigDepends or []);
    };
  });
  isEnabled = x: x.enabled or true;
  allPackages = with builtins; filter isEnabled (map checkExtraDeps (stackagePackages ++ extraPackages));
in allPackages
