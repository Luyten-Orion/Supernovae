import mummy
import nulid
import norm/[postgres, sqlite, pool]

type
  SInstance* = ref object
    webserv*: Server
    idgen*: ULIDGenerator
    db*: Pool

proc new*(_: typeof SInstance, serv: Server, db: sqlite.DbConn | postgres.DbConn, poolSize: Positive = 4): SInstance =
  result = SInstance(
    webserv: serv,
    idgen: initUlidGenerator(),
    db: newPool(poolSize, db)
  )