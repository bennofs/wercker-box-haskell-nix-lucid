with (import ./haskell-packages.nix);
builtins.filter (x: x != null) [
async
attoparsec
blaze-builder
blaze-html
blaze-markup
cereal
conduit
conduit-extra
data-default
deepseq
deepseq-generics
either
errors
lens
mmorph
monad-loops
network
optparse-applicative
storable-record
text
th-lift
th-lift-instances
xml-conduit
xml-types
zlib
]
