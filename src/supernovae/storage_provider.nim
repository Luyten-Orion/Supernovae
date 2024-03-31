import std/[
  strformat,
  strutils,
  options,
  macros
]

import nulid
import tiny_sqlite

# TODO: Figure out pooling for databases

type
  BaseProvider* = object of RootObj

  SQLiteProvider* = object of BaseProvider
    db*: tiny_sqlite.DbConn

proc initSQLiteProvider*(path: string): SQLiteProvider =
  ## Initializes a SQLite database provider
  result = SQLiteProvider(db: tiny_sqlite.openDatabase(path))

# TODO: Foreign keys, unique combination of columns
template primary*() {.pragma.}
template unique*() {.pragma.}
template indexed*() {.pragma.}

proc establish*[T: BaseProvider, U: ref object](provider: T, obj: U, mine: string): bool =
  ## Establishes a table using an object to define the needed tables
  mixin establishImpl
  provider.establishImpl(obj, mine)

proc deposit*[T: BaseProvider, U: ref object](provider: T, obj: U): bool =
  ## Deposits an object into a database using the corrosponding `depositImpl`
  mixin depositImpl
  provider.depositImpl(obj)

proc extract*[T: BaseProvider, U: ref object | object, V: ref object](provider: T,
  idx: U, obj: var Option[V]) =
  ## Extracts an object from a database using the corrosponding `extractImpl`
  mixin extractImpl
  obj = none(V) # Set the value if the `extractImpl` doesn't succeed
  provider.extractImpl(idx, obj)

# Start of errors for unimplemented functions.
proc establishImpl*[T: BaseProvider, U: ref object](provider: T, obj: U, mine: string): bool {.error:
  &"`{$T}`.`establishImpl` is unimplemented for {$U}.".}
proc depositImpl*[T: BaseProvider, U: ref object](provider: T, obj: U): bool {.error:
  &"`{$T}`.`depositImpl` is unimplemented for {$U}.".}
proc extractImpl*[T: BaseProvider, U: ref object | object, V: ref object](provider: T, idx: U,
  obj: var Option[V]) {.error: &"`{$T}`.`extractImpl` is unimplemented for key {$U} and type {$V}.".}
# End of errors for unimplemented functions.

# Start of SQLite implementation.
proc getDbType*(provider: SQLiteProvider, obj: typedesc[string]): string = "TEXT"
proc getDbType*(provider: SQLiteProvider, obj: typedesc[seq[byte]]): string = "BLOB"
# Limitation of SQLite, special case for uint64?
#proc getDbType*(provider: SQLiteProvider, obj: typedesc[uint64]): string = "BLOB"
proc getDbType*(provider: SQLiteProvider, obj: typedesc[SomeOrdinal]): string = "INTEGER"
proc getDbType*(provider: SQLiteProvider, obj: typedesc[ULID]): string = "BLOB"

proc toDbValue*[T: ULID](val: T): tiny_sqlite.DbValue = toDbValue(val.toBytes)
proc fromDbValue*[T: ULID](val: tiny_sqlite.DbValue, _: typedesc[T]): T = ULID.parse(val.blobVal)

proc establishImpl*[U: ref object](provider: SQLiteProvider, obj: U, mine: string): bool =
  ## Establishes a table using an object to define the needed columns
  var query = "CREATE TABLE IF NOT EXISTS "
  query.add(mine)
  query.add(" (")

  var fields: seq[string]

  for name, field in obj[].fieldPairs:
    var field = name & ' ' & provider.getDbType(typeof(field))

    if field.hasCustomPragma(primary):
      field &= " PRIMARY KEY"

    if field.hasCustomPragma(indexed):
      field &= " INDEXED"

    if field.hasCustomPragma(unique):
      field &= " UNIQUE"

    fields.add(field)

  query.add(fields.join(", "))
  query.add(")")

  provider.db.exec(query)
  return true

# End of SQLite implementation.