import std/[
  strformat, # Used for string concat
  strutils,  # Used for parsing ints
  options,   # Optional return types
  times      # Used for grabbing the current timestamp
]

import nulid # Used for ULID data type

import ./[
  storage_provider # For implementing database deposit and extraction functions
]

# TODO: Maybe an abstraction that lets us group users together?
# would be useful for profile sharing, perhaps (alt accounts)
type
  AccountType* = enum
    Local, External
  
  SessionState* = enum
    Active, Invalid, Expired, IncorrectUser

  Account* = ref object
    # The ID of the account
    uid* {.primary.}: ULID # Account ID, primary
    username* {.unique.}: string # A unique username used for identification
    # Discriminators, should figure out a way to
    # generate it on the db side first to prevent conflicts
    #tag*: string
    typ*: AccountType # A local of external account
    defaultProfile*: ULID # Profile.uid, the default profile shown

  LocalAccount* = ref object
    # Local information used for authentication
    uid* {.primary.}: ULID # Same as 'Account', Account ID, primary
    email* {.unique, indexed.}: string # Unique, indexed
    password*: string # Encrypted using argon2

  Session* = ref object
    # Sessions for local accounts, could be scanned regularly to be
    # cleaned up? Or could check every Nth login instead...
    uid* {.unique.}: ULID # Unique, if not primary, indexed
    owner* {.indexed.}: ULID # Account.uid, indexed
    timestamp*: int64 # Timestamp storing last known usage

  ExternalAccount* = ref object
    # External information used for authentication
    uid* {.primary.}: ULID # Same as 'Account', Account ID, primary
    home*: string # URL of home instance, maybe a reference to a 'Source'?
    authenticatedAt*: int64 # Timestamp so expiry can be checked against

  Profile* = ref object
    # Profiles a user can have, users can have multiple profiles,
    # but must *always* have one
    uid* {.primary.}: ULID # Profile ID, primary
    owner* {.indexed.}: ULID # Account.uid, Account ID, indexed
    displayname*: string # Display name
    bio*: string # About me
    avatar*: string # Profile picture URL?
    # Could use a field to indicate whether it's stored on a CDN or not,
    # to shorten URLs? Something to consider.
    #isCdn*: bool

# TODO: Storage provider support start.
proc depositImpl*(provider: SQLiteProvider, acc: Account): bool =
  discard #provider.db.exec()
# Storage provider support end.

# API implementation start.
# Constructors start.
proc newAccount*(uid: ULID, username: string, typ: AccountType
  ): Account =
  return Account(
    uid: uid,
    username: username,
    typ: typ
  )

proc newLocalAccount*(uid: ULID, email, password: string): LocalAccount =
  return LocalAccount(
    uid: uid,
    email: email,
    password: password
  )

proc newProfile*(uid, owner: ULID, displayname, bio: string): Profile =
  return Profile(
    uid: uid,
    owner: owner,
    displayname: displayname
  )
# Constructors end.

proc authenticate*(account: LocalAccount, uid: ULID, password: string): Option[Session] =
  if account.password != password: # TODO: Argon2
    return none(Session)

  return some(Session(
    uid: uid,
    owner: account.uid,
    timestamp: (getTime() + initDuration(days=1)).toUnix
  ))

# TODO: Encryption for tokens
proc token*(s: Session): string = &"{s.owner}.{s.uid}.{s.timestamp}"

proc verifyToken*(s: Session, token: string): SessionState =
  ## Verifies a session against a given token
  if token.len < 54:
    return SessionState.Invalid

  let
    owner = token[0..<26]
    #uid = token[27..<53] # Unneeded
    timestamp = token[54..^1].parseInt().int64

  if s.token != token:
    if $s.owner != owner:
      return SessionState.IncorrectUser

    elif s.timestamp > timestamp:
      return SessionState.Expired

    else:
      return SessionState.Invalid

  else:
    return SessionState.Active
# API implementation end.