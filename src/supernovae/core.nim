import mummy
import mummy/[
  routers
]

import ./[repositories, ratelimiter]
import ./models/responses

type
  SupernovaeCore* = ref object
    repo*: Repository
    router*: Router
    server*: Server
    ratelimiter*: Limiter = newLimiter()
    registrationStatus*: SupernovaeRegistationsStatus

proc ignite*(core: SupernovaeCore, port: Port, address: string = "localhost") =
  # Starts the supernovae server.
  core.server = newServer(core.router)
  core.server.serve(port, address)

proc extinguish*(core: SupernovaeCore) =
  # Closes the supernovae server.
  core.server.close()
  core.repo.seal()
  core.server = nil

export Port