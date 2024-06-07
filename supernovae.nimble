# Package
version       = "0.1.0"
author        = "Luyten Orion"
description   = "A chat platform implemented in Nim!"
license       = "MIT"
srcDir        = "src"
binDir        = "bin"
bin           = @["supernovae"]

# Dependencies
requires "nim >= 2.0.2"
#requires "https://github.com/nim-works/cps ^= 0.11.0"
requires "https://github.com/tuffnatty/tiny_sqlite#eb6cbba"
requires "libsodium#144d6d8"
requires "taskpools#d4c4313"
requires "mummy >= 0.4.2"
requires "puppy >= 2.1.2"
requires "nulid >= 1.3.0"
requires "https://github.com/Luyten-Orion/jsony#head"
requires "results"