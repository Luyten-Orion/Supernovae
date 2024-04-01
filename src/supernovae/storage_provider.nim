# TODO: Rename to repositories? Seems to be the common name for DB abstractions apparently
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
  ProviderConcept = concept p
    p of BaseProvider

  BaseProvider* = ref object of RootObj

  SQLiteProvider* = ref object of BaseProvider
    db*: tiny_sqlite.DbConn

  MineHandle*[T: ProviderConcept] = ref object
    provider: T
    name: string

template isOpen*(provider: SQLiteProvider): bool = provider.db.isOpen
template close*(provider: SQLiteProvider) = provider.db.close

proc initSQLiteProvider*(path: string): SQLiteProvider =
  ## Initializes a SQLite database provider
  result = SQLiteProvider(db: tiny_sqlite.openDatabase(path))

# TODO: Foreign keys, unique combination of columns
template primary*() {.pragma.}
template unique*() {.pragma.}
template indexed*() {.pragma.}

proc establish*[T: BaseProvider, U: ref object](provider: T, obj: typedesc[U], mine: string): MineHandle[T] =
  ## Establishes a table using an object to define the needed tables
  mixin establishImpl
  provider.establishImpl(obj, mine)

proc deposit*[T: BaseProvider, U: ref object](mine: MineHandle[T], obj: U): bool =
  ## Deposits an object into a database using the corrosponding `depositImpl`
  mixin depositImpl
  depositImpl(mine, obj)

proc extract*[T: BaseProvider, U: ref object | object, V: ref object](mine: MineHandle[T],
  idx: U, obj: var Option[V]) =
  ## Extracts an object from a database using the corrosponding `extractImpl`
  mixin extractImpl
  obj = none(V) # Set the value if the `extractImpl` doesn't succeed
  extractImpl(mine, idx, obj)

# Start of errors for unimplemented functions.
proc establishImpl*[T: BaseProvider, U: ref object](provider: T, obj: typedesc[U], mine: string
  ): MineHandle[T] {.error: &"`{$T}`.`establishImpl` is unimplemented for {$U}.".}
proc depositImpl*[T: BaseProvider, U: ref object](provider: T, obj: U): bool {.error:
  &"`{$T}`.`depositImpl` is unimplemented for {$U}.".}
proc extractImpl*[T: BaseProvider, U: ref object | object, V: ref object](mine: MineHandle[T], idx: U,
  obj: var Option[V]) {.error: &"`{$T}`.`extractImpl` is unimplemented for key {$U} and type {$V}.".}
# End of errors for unimplemented functions.

# Start of SQLite implementation.
proc toDbType(val: tiny_sqlite.DbValue): string =
  if val.kind == sqliteInteger:
    result = "INTEGER"

  elif val.kind == sqliteReal:
    result = "REAL"

  elif val.kind == sqliteText:
    result = "TEXT"

  elif val.kind == sqliteBlob:
    result = "BLOB"

  else:
    discard

proc toDbValue*[T: ULID](val: T): tiny_sqlite.DbValue = toDbValue(@(val.toBytes))
proc fromDbValue*(val: tiny_sqlite.DbValue, T: typedesc[ULID]): T = ULID.fromBytes(val.blobVal)

proc establishImpl*[U: ref object](provider: SQLiteProvider, obj: typedesc[U], mine: string): MineHandle[SQLiteProvider] =
  ## Establishes a table using an object to define the needed columns
  # TODO: Migrations?
  var query = "CREATE TABLE IF NOT EXISTS "
  query.add(mine)
  query.add(" (")

  var fields: seq[string]
  var indexes: seq[string]

  for name, field in default(obj)[].fieldPairs:
    var fieldStr = name & " " & toDbValue(default(typeof(field))).toDbType()

    if field.hasCustomPragma(primary):
      fieldStr &= " PRIMARY KEY"

    # TODO: Broken, look at https://www.w3schools.com/sql/sql_create_index.asp on how to create indexes
    if field.hasCustomPragma(indexed):
      fieldStr &= " INDEX"

    if field.hasCustomPragma(unique):
      fieldStr &= " UNIQUE"

    fields.add(fieldStr)

  query.add(fields.join(", "))
  query &= ");" & indexes.join(";") & ";"

  try:
    provider.db.exec(query)
    MineHandle[SQLiteProvider](provider: provider, name: mine)

  except SqliteError as e:
    raise newException(SqliteError, &"Original error: {e.msg}\nQuery: {query}", e)

# End of SQLite implementation.