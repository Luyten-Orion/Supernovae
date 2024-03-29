import std/[
  strformat,
  strutils,
  options,
  macros
]

import nulid
# TODO: Use lower level bindings so we aren't limited to the higher level wrapper?
import lowdb/sqlite

# TODO: Figure out pooling for databases

type
  DbValues = sqlite.DbValue

  BaseProvider* = object of RootObj

  SQLiteProvider* = object of BaseProvider
    db*: sqlite.DbConn

# TODO: Foreign keys
template primary*() {.pragma.}
template unique*() {.pragma.}
template indexed*() {.pragma.}

proc getDbTypeInternal[T: BaseProvider, U: ref object | object](provider: T,
  typ: typedesc[U]): string =
  ## Returns the type mapped to the appropriate db type
  mixin getDbType
  provider.getDbType(typ)

proc getDbValueInternal[T: BaseProvider, U: ref object | object](provider: T,
  val: U): DbValues =
  ## Returns the value represented as the db type
  mixin getDbValue
  provider.getDbValue(val)

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
proc getDbType*[T: BaseProvider, U: ref object | object](provider: T, typ: typedesc[U]): string {.error:
  &"`{$T}`.`getDbType` is unimplemented for {$U}.".}
proc getDbValue*[T: BaseProvider, U: ref object | object](provider: T, val: U): string {.error:
  &"`{$T}`.`getDbValue` is unimplemented for {$U}.".}
proc establishImpl*[T: BaseProvider, U: ref object](provider: T, obj: U, mine: string): bool {.error:
  &"`{$T}`.`establishImpl` is unimplemented for {$U}.".}
proc depositImpl*[T: BaseProvider, U: ref object](provider: T, obj: U): bool {.error:
  &"`{$T}`.`depositImpl` is unimplemented for {$U}.".}
proc extractImpl*[T: BaseProvider, U: ref object | object, V: ref object](provider: T, idx: U,
  obj: var Option[V]) {.error: &"`{$T}`.`extractImpl` is unimplemented for key {$U} and type {$V}.".}
# End of errors for unimplemented functions.

# Start of SQLite implementation.
proc getDbType*(provider: SQLiteProvider, typ: typedesc[string]): string = "TEXT"
proc getDbValue*(provider: SQLiteProvider, val: string): sqlite.DbValue = dbValue(val)

proc getDbType*(provider: SQLiteProvider, typ: typedesc[ULID]): string = "BLOB"
proc getDbValue*(provider: SQLiteProvider, val: ULID): sqlite.DbValue =
  dbValue(cast[sqlite.DbBlob](val.toBytes()))

proc getDbType*(provider: SQLiteProvider, typ: typedesc[seq[byte]]): string = "BLOB"
proc getDbValue*(provider: SQLiteProvider, val: seq[byte]): sqlite.DbValue =
  dbValue(cast[sqlite.DbBlob](val))

proc getDbType*(provider: SQLiteProvider, typ: typedesc[bool]): string = "INTEGER"
proc getDbValue*(provider: SQLiteProvider, val: bool): sqlite.DbValue = dbValue(val.int8)

proc getDbType*(provider: SQLiteProvider, typ: typedesc[SomeInteger]): string = "INTEGER"
proc getDbValue*(provider: SQLiteProvider, val: SomeInteger): sqlite.DbValue = dbValue(val)

proc getDbType*(provider: SQLiteProvider, typ: typedesc[SomeFloat]): string = "REAL"
proc getDbValue*(provider: SQLiteProvider, val: SomeFloat): sqlite.DbValue = dbValue(val)


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

  try:
    provider.db.exec(sql(query))
  except sqlite.DbError:
    return false
# End of SQLite implementation.