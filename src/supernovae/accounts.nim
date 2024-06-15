## Implements a basic account system and the functionality required to manage it.
import std/[
  options, # Optional return types
  times    # Used for grabbing the current timestamp
]

import libsodium/sodium # Used for password hashing.
import nulid            # Used for ULID data type

import ./[
  repositories # For implementing database deposit and extraction functions
]

# TODO: Maybe an abstraction that lets us group users together?
# would be useful for profile sharing, perhaps (alt accounts)
type
  AccountType* = enum
    Local, External

  AccountFlags* {.size(sizeof(byte)).} = enum
    ## Flags an account can have.
    AwaitingApproval ## Account is awaiting approval by admin.
    ## Account has been verified as an official account recognised by the
    ## instance admins.
    Verified
    Architect ## Account belongs to a server admin.
    Servitor ## Account belongs to a bot or another service.
  
  SessionState* = enum
    ## The possible states of a session
    Active, Invalid, Expired

  Account* = ref object
    # An account type used for access to an instance.
    uid* {.primary.}: ULID # Account ID, primary
    username* {.unique.}: string # A unique username used for identification
    # Discriminators, should figure out a way to
    # generate it on the db side first to prevent conflicts
    #tag*: string
    flags*: set[AccountFlags] # Flags that an account can have
    typ*: AccountType # A local of external account
    defaultProfile*: ULID # Profile.uid, the default profile shown

  LocalAccount* = ref object
    # Local information used for authentication
    uid* {.primary.}: ULID # Same as 'Account', Account ID, primary
    email* {.unique.}: string # Unique
    password*: string # Hashed using argon2

  Session* = ref object
    # Sessions for local accounts, possibly external accounts, could be scanned regularly to be
    # cleaned up? Or could check every Nth login instead...
    uid* {.primary.}: ULID # Session ID, primary
    owner*: ULID # Account.uid
    timestamp*: int64 # Timestamp for when the session expires

  ExternalAccount* = ref object
    # External information used for authentication
    uid* {.primary.}: ULID # Same as 'Account', Account ID, primary
    home*: string # URL of home instance, maybe a reference to a 'Source' type?
    # Timestamp so expiry can be checked against
    # TODO: Flesh this system out
    authenticatedAt*: int64

  Profile* = ref object
    # Profiles a user can have, users can have multiple profiles,
    # but must *always* have one
    uid* {.primary.}: ULID # Profile ID, primary
    owner*: ULID # Account.uid, Account ID
    displayname*: string # Display name
    bio*: string # About me
    avatar*: string # Profile picture URL?
    # Could use a field to indicate whether it's stored on a CDN or not,
    # to shorten URLs? Something to consider.
    #isCdn*: bool

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
  let pwhash = crypto_pwhash_str(password)
  return LocalAccount(
    uid: uid,
    email: email,
    password: pwhash
  )

proc newProfile*(uid, owner: ULID, displayname, bio: string): Profile =
  return Profile(
    uid: uid,
    owner: owner,
    displayname: displayname,
    bio: bio
  )
# Constructors end.

proc verify*(account: LocalAccount, password: string): bool =
  ## Alias for `crypto_pwhash_str_verify(account.password, password)`
  crypto_pwhash_str_verify(account.password, password)

proc authenticate*(account: LocalAccount, uid: ULID, password: string): Option[Session] =
  ## `account` is the account to be authenticated.
  ## `uid` is the ID of the session.
  ## `password` is the password of to be checked against.
  if not account.verify(password):
    return none(Session)

  return some(Session(
    uid: uid,
    owner: account.uid,
    timestamp: (getTime() + initDuration(days=1)).toUnix
  ))

# Was originally going to encrypt tokens, but decided against it.
proc token*(s: Session): string = $s.uid

proc verifyToken*(s: Session, token: string): SessionState =
  ## Verifies a session against a given token
  if $s.uid != token:
    return SessionState.Invalid

  elif s.timestamp < getTime().toUnix:
    return SessionState.Expired

  return SessionState.Active

# API implementation end.