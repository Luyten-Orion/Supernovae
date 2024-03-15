import results
import mummy
import nulid
import norm/[postgres, sqlite, pool]

type
  DbConns = sqlite.DbConn | postgres.DbConn

  SInstance*[D: DbConns] = ref object
    webserv*: Server
    idgen*: ULIDGenerator
    db*: Pool[D]

proc new*(_: typeof SInstance, serv: Server, db: DbConns, poolSize: Positive = 4): SInstance =
  result = SInstance(
    webserv: serv,
    idgen: initUlidGenerator(),
    db: newPool(poolSize, db)
  )

export results