## Implements the logic for the SQLite repository.
import std/[strformat, strutils, macros]

import nulid
import jsony
import tiny_sqlite

import ./base

# ? Start of SQLite Repository implementation.
type
  SQLiteRepository* = ref object of BaseRepository
    db*: tiny_sqlite.DbConn

proc toDbType(val: tiny_sqlite.DbValue): string =
  case val.kind
    of sqliteInteger: "INTEGER"
    of sqliteReal: "REAL"
    of sqliteText: "TEXT"
    of sqliteBlob: "BLOB"
    of sqliteNull: raise newException(ValueError, "Value can't be nil!")

proc toDbValue*[T: ULID](val: T): tiny_sqlite.DbValue = toDbValue(@(val.toBytes))
proc fromDbValue*(val: tiny_sqlite.DbValue, T: typedesc[ULID]): T = ULID.fromBytes(val.blobVal)

proc toDbValue*[T: set](val: T): tiny_sqlite.DbValue =
  toDbValue(val.toJson)

proc fromDbValue*[T: set](val: tiny_sqlite.DbValue, _: typedesc[T]): T =
  fromJson(val.strVal, T)

proc initSQLiteRepositoryImpl*(path: string): SQLiteRepository =
  ## Initializes a SQLite database provider
  result = SQLiteRepository(db: tiny_sqlite.openDatabase(path))

proc isUnsealedImpl*(provider: SQLiteRepository): bool =
  ## Returns true if the database is open, false otherwise.
  provider.db.isOpen
proc sealImpl*(provider: SQLiteRepository) =
  ## Closes the database.
  provider.db.close

proc establishImpl*[U: ref object](provider: SQLiteRepository, obj: typedesc[U]) =
  ## Establishes a table using an object to define the needed columns.
  # TODO: Migrations?
  var
    # TODO: Avoid string interpolation? Not a concern since no input is from an untrusted source
    query = &"CREATE TABLE IF NOT EXISTS {$U} ("
    fields, indexes: seq[string]

  for fname, field in new(obj)[].fieldPairs:
    const name: string = fname
    var fieldStr = name & " " & toDbValue(field).toDbType()

    if field.hasCustomPragma(primary):
      fieldStr &= " PRIMARY KEY"

    if field.hasCustomPragma(unique):
      fieldStr &= " UNIQUE"

    if field.hasCustomPragma(uniqueIndex):
      indexes.add &"CREATE UNIQUE INDEX IF NOT EXISTS uidx_{$U}_{name} ON {$U} ({name})"

    if field.hasCustomPragma(index):
      indexes.add &"CREATE INDEX IF NOT EXISTS idx_{$U}_{name} ON {$U} ({name})"

    fields &= fieldStr

  query &= fields.join(", ") & "); " & indexes.join(";")

  when defined(supernovaeEchoSqlStmts):
    debugEcho query

  try:
    provider.db.execScript(query)

  except SqliteError as e:
    raise newException(SqliteError, &"Original error: {e.msg}\nQuery: {query}", e)

proc depositImpl*[U: ref object](provider: SQLiteRepository, obj: U) =
  ## Deposits an object into an SQLite table.
  var
    query = "INSERT INTO " & $U & " ("
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

  when defined(supernovaeEchoSqlStmts):
    debugEcho query

  try:
    provider.db.exec(query, values & values[1..^1])
  except SqliteError as e:
    raise newException(SqliteError, &"Original error: {e.msg}\nQuery: {query}", e)

# TODO: More complex/flexible queries
proc extractImpl*[U: ref object, V](provider: SQLiteRepository, obj: typedesc[U],
  idx: V, limit: Natural = 0): seq[U] =
  ## Extracts an object from an SQLite table.
  var
    query = "SELECT * FROM " & $U & " WHERE "

  var tmp: U
  new(tmp)

  for name, field in tmp[].fieldPairs:
    query.add name & " = ?"
    break

  if limit > 0:
    query &= " LIMIT ?"
  
  query &= ";"

  when defined(supernovaeEchoSqlStmts):
    debugEcho query

  let rows = if limit != 0:
    provider.db.all(query, params = [idx.toDbValue, limit.toDbValue])

  else:
    provider.db.all(query, params = [idx.toDbValue])

  for row in rows:
    var res = new obj

    for name, field in res[].fieldPairs:
      field = fromDbValue(row[name], typeof(field))

    result.add res