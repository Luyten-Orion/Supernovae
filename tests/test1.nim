import std/unittest

import mummy
import mummy/routers
import norm/sqlite

import supernovae/[accounts, models, core]

proc indexHandler(request: Request) =
  var headers: HttpHeaders
  headers["Content-Type"] = "text/plain"
  request.respond(200, headers, "Hello, World!")

var router: Router
router.get("/", indexHandler)

let server = newServer(router)
var db = open("supernovae.db", "", "", "")
var inst = newSupernovae[:typeof(db)](server, db)