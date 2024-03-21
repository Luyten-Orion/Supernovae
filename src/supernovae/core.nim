import malebolgia
import results
import mummy
import nulid
import norm/[postgres, sqlite, pool]

type
  DbConns* = sqlite.DbConn | postgres.DbConn

  SInstance*[Db: DbConns] = ref object
    threadpool*: Master
    webserv*: Server
    idgen*: ULIDGenerator
    db*: Pool[Db]

proc newSupernovae*[Db: DbConns](serv: Server, db: Db,
  poolSize: Positive = 4): SInstance[Db] =
  result = SInstance[Db](
    threadpool: createMaster(),
    webserv: serv,
    idgen: initUlidGenerator(),
    db: newPool(poolSize, proc(): Db = db)
  )

export results