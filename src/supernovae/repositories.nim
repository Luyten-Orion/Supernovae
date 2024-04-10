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
  Repositories = concept p
    p of BaseRepository

  #? Could remove `BaseRepository` entirely and use the `Repositories` concept?
  BaseRepository* = ref object of RootObj

  SQLiteRepository* = ref object of BaseRepository
    db*: tiny_sqlite.DbConn

  MineHandle*[T: Repositories] = ref object
    # TODO: Support index querying automatically?
    provider: T
    name: string

template isOpen*(provider: SQLiteRepository): bool = provider.db.isOpen
template close*(provider: SQLiteRepository) = provider.db.close

proc initSQLiteRepository*(path: string): SQLiteRepository =
  ## Initializes a SQLite database provider
  result = SQLiteRepository(db: tiny_sqlite.openDatabase(path))

# TODO: Foreign keys, multi-column constraint/indexes
template primary*() {.pragma.}
template unique*() {.pragma.}
template index*() {.pragma.}
template uniqueIndex*() {.pragma.}

# TODO: Wrap errors into enum/`Result`s instead of relying on exceptions for cleaner code
proc establish*[T: Repositories, U: ref object](provider: T, obj: typedesc[U], mine: string): MineHandle[T] =
  ## Establishes a table using an object to define the needed tables
  mixin establishImpl
  provider.establishImpl(obj, mine)

proc deposit*[T: Repositories, U: ref object](mine: MineHandle[T], obj: U) =
  ## Deposits an object into a database using the corrosponding `depositImpl`
  mixin depositImpl
  depositImpl(mine, obj)

proc extract*[T: Repositories, U: ref object | object, V](mine: MineHandle[T], obj: typedesc[V],
  idx: U, limit: Natural = 0): seq[V] =
  ## Extracts an object from a database using the corrosponding `extractImpl`
  mixin extractImpl
  result = extractImpl(mine, obj, idx, limit)

# Start of fallback implementation.
proc establishImpl*[T: Repositories, U: ref object](provider: T, obj: typedesc[U], mine: string
  ): MineHandle[T] {.error: &"`{$T}`.`establishImpl` is unimplemented for {$U}.".}
proc depositImpl*[T: Repositories, U: ref object](provider: T, obj: U) {.error:
  &"`{$T}`.`depositImpl` is unimplemented for {$U}.".}
proc extractImpl*[T: Repositories, U: ref object | object, V](mine: MineHandle[T], obj: typedesc[V],
  idx: U, limit: Natural = 0): seq[V] {.error: &"`{$T}`.`extractImpl` is unimplemented for key {$U} and type {$V}.".}
# End of fallback implementation.

# Start of SQLite implementation.
proc toDbType(val: tiny_sqlite.DbValue): string =
  case val.kind
    of sqliteInteger: "INTEGER"
    of sqliteReal: "REAL"
    of sqliteText: "TEXT"
    of sqliteBlob: "BLOB"
    of sqliteNull: raise newException(ValueError, "Value can't be nil!")

proc toDbValue*[T: ULID](val: T): tiny_sqlite.DbValue = toDbValue(@(val.toBytes))
proc fromDbValue*(val: tiny_sqlite.DbValue, T: typedesc[ULID]): T = ULID.fromBytes(val.blobVal)

# TODO: Move SQLite-related code to a separate file?
proc establishImpl*[U: ref object](provider: SQLiteRepository, obj: typedesc[U], mine: string): MineHandle[SQLiteRepository] =
  ## Establishes a table using an object to define the needed columns
  # TODO: Migrations?
  var
    # TODO: Avoid string interpolation? Not a concern since no input is from an untrusted source
    query = &"CREATE TABLE IF NOT EXISTS {mine} ("
    fields, indexes: seq[string]

  for fname, field in new(obj)[].fieldPairs:
    const name: string = fname
    var fieldStr = name & " " & toDbValue(field).toDbType()

    if field.hasCustomPragma(primary):
      fieldStr &= " PRIMARY KEY"

    if field.hasCustomPragma(unique):
      fieldStr &= " UNIQUE"

    if field.hasCustomPragma(uniqueIndex):
      indexes.add &"CREATE UNIQUE INDEX IF NOT EXISTS uidx_{mine}_{name} ON {mine} ({name})"

    if field.hasCustomPragma(index):
      indexes.add &"CREATE INDEX IF NOT EXISTS idx_{mine}_{name} ON {mine} ({name})"

    fields &= fieldStr

  query &= fields.join(", ") & "); " & indexes.join(";")

  when defined(echoSqlStatements):
    debugEcho query

  try:
    provider.db.execScript(query)
    MineHandle[SQLiteRepository](provider: provider, name: mine)

  except SqliteError as e:
    raise newException(SqliteError, &"Original error: {e.msg}\nQuery: {query}", e)

proc depositImpl*[U: ref object](mine: MineHandle[SQLiteRepository], obj: U) =
  ## Deposits an object into an SQLite table
  var
    query = "INSERT INTO " & mine.name & " ("
    fields: seq[string]
    values: seq[tiny_sqlite.DbValue]

  for name, field in obj[].fieldPairs:
    fields.add name
    values.add toDbValue(field)

  query &= fields.join(", ") & ") VALUES (" & repeat("?", values.len).join(", ") & ") ON CONFLICT("
  query &= fields[0] & ") DO UPDATE SET " & fields[0] & " = excluded." & fields[0]

  for i in fields[1..^1]:
    query &= ", " & i & " = ?"

  query &= ";"

  when defined(echoSqlStatements):
    debugEcho query

  try:
    mine.provider.db.exec(query, values & values[1..^1])
  except SqliteError as e:
    raise newException(SqliteError, &"Original error: {e.msg}\nQuery: {query}", e)

# TODO: More complex/flexible queries
proc extractImpl*[U: ref object | object, V](mine: MineHandle[SQLiteRepository], obj: typedesc[V],
  idx: U, limit: Natural = 0): seq[V] =
  ## Extracts an object from an SQLite table
  var
    query = "SELECT * FROM " & mine.name & " WHERE "

  for name, field in default(V)[].fieldPairs:
    query.add name & " = ?"
    break

  if limit > 0:
    query &= " LIMIT ?"
  
  query &= ";"

  when defined(echoSqlStatements):
    debugEcho query

  let rows = if limit != 0:
    mine.provider.db.all(query, params = [idx.toDbValue, limit.toDbValue])

  else:
    mine.provider.db.all(query, params = [idx.toDbValue])

  for row in rows:
    var res = new obj

    for name, field in res[].fieldPairs:
      field = fromDbValue(row[name], typeof(field))

    result.add res

# End of SQLite implementation.