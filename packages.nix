with (import ./lucid-haskell-packages.nix);
builtins.filter (x: x != null) [
QuickCheck
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
http-conduit
lens
mmorph
monad-loops
network
optparse-applicative
regex-applicative
storable-record
tasty
tasty-hunit
tasty-th
tasty-quickcheck
text
th-lift
th-lift-instances
vector
vector-th-unbox
wreq
xml-conduit
xml-lens
xml-types
zlib
]
