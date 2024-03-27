import std/[
  options, # Optional return types
  tables   # Used for storing session IDs and timestamp authentication
]

import nulid # Used for ULID data type

#[
TODO: A
]#


# TODO: Maybe an abstraction that lets us group users together?
# would be useful for profile sharing, perhaps (alt accounts)
type
  AccountType* = enum
    Local, External

  Account* = ref object
    # The ID of the account
    uid*: ULID # Unique, if not primary, indexed
    username*: string # A unique username used for identification
    # Discriminators, should figure out a way to
    # generate it on the db side first to prevent conflicts
    #tag*: string
    typ*: AccountType # A local of external account
    defaultProfile*: ULID # Profile.uid, the default profile shown

  LocalAccount* = ref object
    # Local information used for authentication
    uid*: ULID # Same as 'Account', unique, if not primary, indexed
    email*: string # Unique, indexed
    password*: string # Encrypted using argon2

  Session* = ref object
    # Sessions for local accounts, could be scanned regularly to be
    # cleaned up? Or could check every Nth login instead...
    uid*: ULID # Unique, if not primary, indexed
    owner*: ULID # Account.uid, indexed
    timestamp*: int64 # Timestamp storing last known usage

  ExternalAccount* = ref object
    # External information used for authentication
    uid*: ULID # Same as 'Account', unique, if not primary, indexed
    home*: string # URL of home instance, maybe a reference to a 'Source'?
    authenticatedAt*: int64 # Timestamp so expiry can be checked against

  Profile* = ref object
    # Profiles a user can have, users can have multiple profiles,
    # but must *always* have one
    uid*: ULID # Unique, if not primary, indexed
    owner*: ULID # Account.uid
    displayname*: string # Display name
    bio*: string # About me
    avatar*: string # Profile picture URL?
    # Could use a field to indicate whether it's stored on a CDN or not,
    # to shorten URLs? Something to consider.
    #isCdn*: bool

# API implementation start.
# Constructors start.
proc new*(_: typeof Account, uid: ULID, username: string, typ: AccountType
  ): Account =
  return Account(
    uid: uid,
    username: username,
    typ: typ
  )

proc new*(_: typeof LocalAccount, uid: ULID, email, password: string): LocalAccount =
  return LocalAccount(
    uid: uid,
    email: email,
    password: password
  )

proc new*(_: typeof Profile, uid, owner: ULID, displayname, bio: string): Profile =
  return Profile(
    uid: uid,
    owner: owner,
    displayname: displayname
  )
# Constructors end.

proc authenticate*(account: LocalAccount, password: string): Option[Session] =
  discard
