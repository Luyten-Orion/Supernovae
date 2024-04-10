# TODO: Restructure code
# TODO: Use a logging library
from std/json import `%*`

import jsony
import mummy
import mummy/[
  routers
]

import ./supernovae/[constants, repositories]

var repo = initSQLiteRepository("supernovae.db")
var router: Router

# TODO: Figure out a better way to define API routes
proc apiRoot(request: Request) =
  var headers: HttpHeaders
  headers["Content-Type"] = "application/json"
  request.respond(200, headers, "{\"version\":\"" & SNVersion & "\"}")

proc accountsRoot(request: Request) =
  var headers: HttpHeaders
  headers["Content-Type"] = "text/plain"
  request.respond(200, headers, "Hello, World!")

router.get("/api", apiRoot)

let server = newServer(router)
echo "Serving on http://localhost:8080"
server.serve(Port(8080))