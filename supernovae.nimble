# Package

import ./src/supernovae/constants

version = SNVersion
author        = "Yu-Vitaqua-fer-Chronos"
description   = "A chat platform implemented in Nim!"
license       = "MIT"
srcDir        = "src"
bin           = @["supernovae"]

# Dependencies

requires "nim >= 2.0.2"
#requires "https://github.com/nim-works/cps ^= 0.11.0"
requires "https://github.com/tuffnatty/tiny_sqlite#eb6cbba"
requires "libsodium#144d6d8"
requires "mummy >= 0.4.1"
requires "nulid >= 1.3.0"
requires "jsony >= 1.1.5"
requires "results"