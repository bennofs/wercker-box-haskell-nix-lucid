let
  pkgs = import <nixpkgs> { config = {}; };
  isEnabled = x: x == null || ! x ? pname ||
    (if x ? enabled then x.enabled else builtins.throw "${x.pname} has no enabled");
  haskellPackages = (import ./lucid-haskell-packages.nix).override (old: {
    overrides = self: super:
      let super = (old.overrides or (_: _: {})) self super;
      in super // {
        mkDerivation = args: super.mkDerivation (args // {
          passthru = with pkgs.lib; with builtins; {
            enabled =
              let nativeDeps = args.extraLibraries or [] ++ args.pkgconfigDepends or [];
              in all isEnabled (args.buildDepends or []) &&
                 [] == filter (x: x != null) nativeDeps;
          };
        });
      };
  });
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
  extraPackages = with haskellPackages; [ storable-record lens conduit errors optparse-applicative ];
  allPackages = with builtins; filter isEnabled extraPackages;
in allPackages
