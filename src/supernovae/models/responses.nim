import jsony

import ../constants

type
  SupernovaeRegistationsStatus* = enum
    snOpen, snGated, snClosed

  SupernovaeInstanceMeta* = object
    version*: string = SNVersion
    registrations*: SupernovaeRegistationsStatus

func dumpHook*(v: var string, e: SupernovaeRegistationsStatus) =
  v.add case e
  of snOpen: "open"
  of snGated: "gated"
  of snClosed: "closed"

func parseHook*(s: string, i: var int, v: var SupernovaeRegistationsStatus) =
  var res: string
  parseHook(s, i, res)

  v = case res
  of "open": snOpen
  of "gated": snGated
  of "closed": snClosed
  else: raise newException(ValueError, "Invalid registration status: " & res)