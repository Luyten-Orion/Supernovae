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
    hits*: range[0..high(uint8).int]
    cooldown*: Duration

  Limiter* = TableRef[string, Table[string, Limit]]

proc newLimiter*(): Limiter =
  ## Creates a new limiter instance.
  newTable[string, Table[string, Limit]]()

proc checkImpl(limiter: Limiter, endpoint: string, maxHits: Limit.hits, uid: string, cooldown: Duration): int64 =
  # Create the limiter for the endpoint if it doesn't exist.
  if not limiter.hasKey(endpoint):
    limiter[endpoint] = initTable[string, Limit]()

  # Check if the given uid is in the limiter, create it if it doesn't exist.
  if not limiter[endpoint].hasKey(uid):
    limiter[endpoint][uid] = Limit(cooldown: cooldown, hits: 0, waitTime: now() - initDuration(weeks=1000))

  let limit = limiter[endpoint][uid]

  # Set the time the endpoint was last accessed so that it can be deleted.
  limit.lastAccessed = now()

  # Check if the limit has been hit.
  if limit.hits >= maxHits:
    limit.hits = 1
    # Set the cooldown if the ratelimit has been hit.
    limit.waitTime = now() + limit.cooldown
    return (now() - limit.waitTime).inSeconds

  # Reset the limiter if the elapsed time has exceeded the cooldown.
  if now() < limit.waitTime:
    return (now() - limit.waitTime).inSeconds

  inc limit.hits
  return 0

# TODO: Logic for a cycler that clears out entries that haven't been accessed in a while?
proc check*(limiter: Limiter, endpoint: string, maxHits: Limit.hits, uid: string, cooldown: Duration): int64 =
  ## Returns the duration left until the request can be made, will return 0 if the request can be made just fine.
  when not defined(supernovaeNoRateLimiter):
    checkImpl(limiter, endpoint, maxHits, uid, cooldown)
  else:
    0