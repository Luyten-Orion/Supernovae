import malebolgia
import results
import mummy
import nulid
import norm/[postgres, sqlite, pool]

type
  DbConns = sqlite.DbConn | postgres.DbConn

  SInstance*[D: DbConns] = ref object
    threadpool*: MasterHandle
    webserv*: Server
    idgen*: ULIDGenerator
    db*: Pool[D]

proc new*(_: typeof SInstance, masterHandle: MasterHandle, serv: Server,
    db: DbConns, poolSize: Positive = 4): SInstance =
  result = SInstance(
    threadpool: masterHandle,
    webserv: serv,
    idgen: initUlidGenerator(),
    db: newPool(poolSize, db)
  )

export results