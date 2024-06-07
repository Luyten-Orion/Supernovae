import mummy
import mummy/[
  routers
]

import ./[repositories]
import ./models/responses

type
  SupernovaeCore*[T: Repositories] = ref object
    repo*: T
    router*: Router
    registrationStatus*: SupernovaeRegistationsStatus

proc ignite*(core: SupernovaeCore, port: Port, address: string = "localhost") =
  var server = newServer(core.router)
  server.serve(port, address)