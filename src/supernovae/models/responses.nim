## Defines the the models used for responses from the server.
## TODO: Split this into several submodules for different functionalities?
import std/strutils

import ../constants

type
  SupernovaeRegistationsStatus* = enum
    ## The user registration status of the supernovae instance.
    Open = "open", Gated = "gated", GatedLocal = "gated-local",
    GatedExternal = "gated-external", Closed = "closed"

  SupernovaeInstanceMeta* = object
    ## The metadata for the supernovae instance, used for the root API response.
    version*: string = SNVersion
    registrations*: SupernovaeRegistationsStatus

proc `$`*(status: SupernovaeRegistationsStatus): string =
  case status
  of Open: "Open"
  of Gated: "Gated"
  of GatedLocal: "GatedLocal"
  of GatedExternal: "GatedExternal"
  of Closed: "Closed"