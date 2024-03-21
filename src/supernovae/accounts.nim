import std/random

import libsodium/sodium
import malebolgia
import nulid
import norm/[postgres, sqlite, pool]

import ./[models, core]
# TODO: Implement this.
# For now, the file will contain a skeleton of how I want the API to look like.

const
  TagChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
  EmptyUlid = ULID()

type
  RollbackError = postgres.RollbackError | sqlite.RollbackError

  AccountCreationError* = enum
    DuplicatedUserID, EmailAlreadyInUse, AccountFromProviderInUse, 

proc tagGenerator: string =
  # TODO: Accept params to exclude certain characters from samples when used together
  # Note: Seems like it'd be excessive to do this...
  result.setLen(6)
  
  for i in 0..<result.len:
    result[i] = sample(TagChars)

proc ensureAccountDoesntExist(inst: SInstance, db: DbConns, email, username,
  provider: AccountProvider): Result[tuple[acc: ULID, profile: ULID], AccountCreationError] =
  # Wah
  # The sequences where select queries return results
  var
    accRes: seq[Account]
    accSrcRes: seq[AccountSource]
    localAccRes: seq[LocalAccount]
    profileRes: seq[Profile]

    tag = "000000"
    accUid = EmptyUlid
    profileUid = EmptyUlid

  # Validation
  # First loop: Check for unique IDs
  while true:
    let
      accUid = inst.idgen.ulid()

    db.select(accRes, "Account.uid = ?", accUid)
    db.select(accSrcRes, "AccountSource.owner = ?", accUid)
    db.select(localAccRes, "LocalAccount.uid = ?", accUid)
    db.select(profileRes, "Profile.owner = ? OR Profile.uid = ?", accUid, profileUid)

    if accRes.len == 0 and accSrcRes.len == 0 and localAccRes.len == 0 and profileRes.len == 0:
      break

  # TODO: Add more validation

    db.select()

proc createLocalAccount*(inst: SInstance, username, email, password: string): Result[Account, string] =
  var passwordHash: string

  # TODO: How do we know when a value has been returned...?
  inst.threadpool.awaitAll:
    inst.threadpool.spawn crypto_pwhash_str(password) -> passwordHash

  var
    account = Account(uid: EmptyUlid, defaultProfile: EmptyUlid, username: username, tag: "")
    accSrc = AccountSource(owner: EmptyUlid, provider: LocalCluster)
    localAcc = LocalAccount(uid: EmptyUlid, email: email, password: passwordHash)
    profile = Profile(uid: EmptyUlid, owner: EmptyUlid, avatar: "", displayname: username, pronouns: "", bio: "")

  inst.db.withDb:
    ensureAccountDoesntExist(inst, db, email, username, LocalCluster)

    try:
      db.transaction:
        db.insert(account)
        db.insert(accSrc)
        db.insert(localAcc)
        db.insert(profile)

    except RollbackError as e:
      return err(e.msg)

  ok(account)