#import mummy
#import norm

import ./supernovae/[
  accounts,
  models,
  core
]

discard compiles(accounts) and compiles(models) and compiles(core)

import mummy
import mummy/routers
import norm/sqlite

proc indexHandler(request: Request) =
  var headers: HttpHeaders
  headers["Content-Type"] = "text/plain"
  request.respond(200, headers, "Hello, World!")

var router: Router
router.get("/", indexHandler)

let server = newServer(router)
var db = open("supernovae.db", "", "", "")
var inst = newSupernovae(server, db)

