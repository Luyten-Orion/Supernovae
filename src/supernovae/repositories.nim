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

  RepoValueKind* = enum
    String, Blob, Int, Float, Bool, ULID_T, Null

  RepoValue = object
    case kind*: RepoValueKind
      of String: strVal*: string
      of Blob: blobVal*: seq[byte]
      of Int: intVal*: int
      of Float: floatVal*: float
      of Bool: boolVal*: bool
      of ULID_T: ulidVal*: ULID
      of Null: discard

proc toRepoValue*(val: string): RepoValue = RepoValue(kind: String, strVal: val)
proc toRepoValue*(val: openArray[byte]): RepoValue = RepoValue(kind: Blob, blobVal: @val)
proc toRepoValue*(val: int): RepoValue = RepoValue(kind: Int, intVal: val)
proc toRepoValue*(val: float): RepoValue = RepoValue(kind: Float, floatVal: val)
proc toRepoValue*(val: bool): RepoValue = RepoValue(kind: Bool, boolVal: val)
proc toRepoValue*(val: ULID): RepoValue = RepoValue(kind: ULID_T, ulidVal: val)

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

# Beginning of query builder code
type
  QueryKind* = enum
    # EQ - Equal
    # NEQ - Not Equal
    # GT - Greater Than
    # LT - Less Than
    # GTE - Greater Than or Equal
    # LTE - Less Than or Equal
    Empty, Select, Where, EQ, NEQ, GT, LT, GTE, LTE

  QueryObj* = object
    case kind*: QueryKind
      of Empty:
        discard

      of Select:
        slCount*, slOffset*: Natural
        slCond*: Query

      of Where:
        whConds*: seq[Query]

      of {EQ, NEQ, GT, LT, GTE, LTE}:
        tgField*: string
        tgValue*: RepoValue

  Query* = ref QueryObj

proc `$`*(query: Query): string =
  if query != nil:
    return $query[]
  "Query(nil)"

macro queryIt*[T: ref object](typ: typedesc[T], body: untyped): Query =
  ## Translates a very limited subset of Nim to a `Query` object which is then used to
  ## provide repository-agnostic access to a database.
  ## The proc's usage can be understood as followed:
  ## `queryIt <Ref Type>: select [limit [, offset],] where <condition>`
  var
    query = Query(kind: Select, slCount: 0, slCond: Query(kind: Where))
    curNode = body
    qNode = newLit(query)

  result = newStmtList(newVarStmt(genSym(nskVar, "query"), qNode))

  if curNode.kind != nnkStmtList:
    error("Query statements must be wrapped in a statement list", body)
    return

  if curNode.len != 1:
    error("Can only have one statement in the query!", body)
    return

  curNode = curNode[0]

  if curNode.kind notin nnkCallKinds or (curNode[0].kind == nnkIdent and curNode[0].strVal != "select"):
    error("Expected a `select` statement!", curNode)
    return

  if curNode.len notin [2, 3, 4]:
    error("Expected anywhere between 1 and 3 arguments in the `select` statement! The limit is optional, but the where clause is not!", curNode)
    return

  if curNode.len == 3:
    result.add newAssignment(
      newDotExpr(result[0][0][0], ident("slCount")),
      curNode[1]
    )

  elif curNode.len == 4:
    result.add newAssignment(
      newDotExpr(result[0][0][0], ident("slCount")),
      curNode[1]
    )
    result.add newAssignment(
      newDotExpr(result[0][0][0], ident("slOffset")),
      curNode[2]
    )

  curNode = curNode[^1]

  if curNode.kind notin nnkCallKinds or (curNode[0].kind == nnkIdent and curNode[0].strVal != "where"):
    error("Expected a `where` statement!", curNode)
    return

  if curNode.len != 2:
    error("Expected the query filters to be after the `where` clause!", curNode)
    return

  curNode = curNode[1]

  var
    nodeQueue = @[curNode]
    i = 0

  while nodeQueue.len > 0:
    let node = nodeQueue.pop()

    if node.kind notin nnkCallKinds:
      error("Expected `and`, `==`, `!=`, `>=`, `<=`, `>` or `<`!", node)
      return

    if node[0].strVal == "and":
      for i in 1..<node.len:
        nodeQueue.add node[i]
      continue

    if node.len != 3:
      error("Expected the field and value to be used for the query!", node)
      return

    var q = Query(kind: case node[0].strVal
      of "==": EQ
      of "!=": NEQ
      of ">=": GTE
      of "<=": LTE
      of ">": GT
      of "<": LT
      else:
        error("Expected `==`, `!=`, `>=`, `<=`, `>` or `<`!", node)
        return
    )

    var
      itField, itCmpValue: NimNode

    if node[1].kind != nnkDotExpr:
      if node[2].kind != nnkDotExpr:
        error("Expected `it` in either side of the query!", node)
        return

      if node[2][0].kind != nnkIdent or node[2][0].strVal != "it":
        error("Expected `it`!", node[2][0])
        return

      if node[2][1].kind != nnkIdent:
        error("Expected access to a field!", node[2][1])
        return

      itField = node[2]
      itCmpValue = node[1]

    else:
      if node[1][0].kind != nnkIdent or node[1][0].strVal != "it":
        error("Expected `it`!", node[1][0])
        return

      if node[1][1].kind != nnkIdent:
        error("Expected access to a field!", node[1][1])
        return

      itField = node[1]
      itCmpValue = node[2]

    q.tgField = itField[1].strVal

    result.add newCall(bindSym"assert", newCall(
      bindSym"is",
      newDotExpr(
        typ,
        ident(q.tgField)
      ),
      newCall(
        bindSym"typeof",
        itCmpValue
      )
    ), newLit("`" & itCmpValue.repr & "` does not match the type of `" & typ.repr & "`!"))

    template newBracketExpr(a: NimNode, b: NimNode): NimNode =
      var n = newNimNode(nnkBracketExpr)
      n.add a
      n.add b
      n

    result.add newAssignment(
      newDotExpr(
        newBracketExpr(
          newDotExpr(
            newDotExpr(
              result[0][0][0],
              ident("slCond")
            ), ident("whConds")
          ),
          newLit(i)
        ),
        ident("tgValue")
      ),
      newCall(
        bindSym"toRepoValue",
        itCmpValue
      )
    )

    query.slCond.whConds.add q
    inc i

  result.add result[0][0][0]

  qNode[] = newLit(query)[]

# Export the pragmas
export primary, unique, index, uniqueIndex