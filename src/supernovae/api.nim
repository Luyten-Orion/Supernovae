import std/json
import jsony
import mummy
import mummy/[
  routers
]

import ./[core, accounts, constants, repositories]
import ./models/responses

template respond[T](request: Request, code: int, headers: HttpHeaders, body: T) =
  request.respond(code, headers, toJson[T](body))

proc establishAnchor*[R: Repositories](core: SupernovaeCore[R]) =
  ## Registers the API endpoints.
  proc apiRoot(request: Request) {.gcsafe.} =
    var headers: HttpHeaders
    headers["Content-Type"] = "application/json"
    request.respond(200, headers, SupernovaeInstanceMeta(registrations: core.registrationStatus))

  

  # Register the API endpoints.
  # TODO: Is '/api' unnecessary?
  core.router.get("/api", apiRoot)
