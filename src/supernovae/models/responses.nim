import jsony

import ../constants

type
  SupernovaeRegistationsStatus* = enum
    Open, Gated, Closed

  SupernovaeInstanceMeta* = object
    version*: string = SNVersion
    registrations*: SupernovaeRegistationsStatus

func dumpHook*(v: var string, e: SupernovaeRegistationsStatus) =
  v.add case e
  of Open: "open"
  of Gated: "gated"
  of Closed: "closed"

func parseHook*(s: string, i: var int, v: var SupernovaeRegistationsStatus) =
  var res: string
  parseHook(s, i, res)

  v = case res
  of "open": Open
  of "gated": Gated
  of "closed": Closed
  else: raise newException(ValueError, "Invalid registration status: " & res)