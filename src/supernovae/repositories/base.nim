## Implements the base logic for the repository.
## TODO: PostgreSQL/other database provider implementation, likely requires me to learn and implementing pooling.
##
## TODO: Figure out pooling for databases.
##
## TODO: Maybe a small SQL statement builder to reduce the amount of string operations done? Example from Debby
## https://github.com/treeform/debby/blob/4ad7f6ecf60ed125672ec8ffa44becfd9c8dbb46/src/debby/common.nim#L260-L313
## We do need to make it so it can be used for multiple types of databases though...

import std/[
  strformat,
  strutils,
  macros
]

import nulid
import tiny_sqlite

# TODO: PostgreSQL/other database provider implementation, likely requires me to learn and implementing pooling.
# TODO: Figure out pooling for databases
# TODO: Maybe a small SQL statement builder to reduce the amount of string operations done? Example from Debby
# https://github.com/treeform/debby/blob/4ad7f6ecf60ed125672ec8ffa44becfd9c8dbb46/src/debby/common.nim#L260-L313

type
  # TODO: Could remove `BaseRepository` entirely and use the `Repositories` concept?
  BaseRepository* = ref object of RootObj

# ? At compile-time, the behaviour of these pragmas is determined by the implementation.
# TODO: Foreign keys, multi-column constraint/indexes
template primary*() {.pragma.}
template unique*() {.pragma.}
template index*() {.pragma.}
template uniqueIndex*() {.pragma.}