## Combines the various repository impls together and provides a basic query API.
import std/macros

import nulid

import repositories/[
  sqlite,
  base
]

type
  RepositoryKind* = enum
    SQLite

  Repository* = ref object
    case kind*: RepositoryKind
      of SQLite: sqlite*: SQLiteRepository

proc initSQLiteRepository*(path: string): Repository =
  Repository(kind: SQLite, sqlite: initSQLiteRepositoryImpl(path))

proc isUnsealed*(repo: Repository): bool =
  case repo.kind
    of SQLite: repo.sqlite.isUnsealedImpl

proc seal*(repo: Repository) =
  case repo.kind
    of SQLite: repo.sqlite.sealImpl

proc establish*[U: ref object](repo: Repository, obj: typedesc[U]) =
  case repo.kind
    of SQLite: repo.sqlite.establishImpl(obj)

proc deposit*[U: ref object](repo: Repository, obj: U) =
  case repo.kind
    of SQLite: repo.sqlite.depositImpl(obj)

proc extract*[U: ref object, V](repo: Repository, obj: typedesc[U],
  idx: V, limit: Natural = 0): seq[U] =
  case repo.kind
    of SQLite: repo.sqlite.extractImpl(obj, idx, limit)

proc excavate*[U: ref object](repo: Repository, obj: typedesc[U],
  query: Query): seq[U] =
  case repo.kind
    of SQLite: repo.sqlite.excavateImpl(obj, query)

# Export the pragmas
export primary, unique, index, uniqueIndex, toRepoValue, QueryObj, Query, QueryKind, `$`, queryIt