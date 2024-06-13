## Defines basic ratelimiting functionality.
##
## TODO: Abstract this to use a database or an actual cache for shared ratelimiting.
##
## TODO: Add an option to disable ratelimiting entirely for if a server implements it
## via something such as a caddy plugin.
import std/[tables, times]

type
  Limit* = ref object
    waitTime*, lastAccessed*: DateTime
    hits, maxHits*: range[0..high(uint8).int]
    cooldown*: Duration

  Limiter* = TableRef[string, Table[string, Limit]]

proc newLimiter*(): Limiter =
  ## Creates a new limiter instance.
  newTable[string, Table[string, Limit]]()

# TODO: Logic for a cycler that clears out entries that haven't been accessed in a while?
proc check*(limiter: Limiter, endpoint: string, uid: string, cooldown: Duration): bool =
  ## Returns true if the request is allowed to proceed, false otherwise.
  # Set the time the endpoint was last accessed so that it can be deleted.
  limiter[endpoint][uid].lastAccessed = now()

  # Create the limiter for the endpoint if it doesn't exist.
  if not limiter.hasKey(endpoint):
    limiter[endpoint] = initTable[string, Limit]()

  # Check if the given uid is in the limiter, create it if it doesn't exist.
  if not limiter[endpoint].hasKey(uid):
    limiter[endpoint][uid] = Limit(cooldown: cooldown, hits: 1)
    return

  let limit = limiter[endpoint][uid]

  # Check if the limit has been hit.
  if limit.hits >= limit.maxHits:
    # Reset the limiter if the elapsed time has exceeded the cooldown.
    if now() >= limit.waitTime:
      limit.hits = 1
      return true

    else:
      # Set the cooldown if the ratelimit has been hit.
      limit.waitTime = now() + limit.cooldown
      return

  inc limit.hits
  return true