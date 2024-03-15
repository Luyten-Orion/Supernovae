import libsodium/sodium
import malebolgia
import nulid
import norm/[postgres, sqlite, pool]

import ./[models, core]
# TODO: Implement this.
# For now, the file will contain a skeleton of how I want the API to look like.

type RollbackError = postgres.RollbackError | sqlite.RollbackError

proc createLocalAccount*(inst: SInstance, username, tag, email, password: string): Result[Account, string] =
  let
    accUid = inst.idgen.ulid()
    profileUid = inst.idgen.ulid()

  var passwordHash: string

  # TODO: How do we know when a value has been returned...?
  inst.threadpool.spawn crypto_pwhash_str(password) -> passwordHash

  var
    account = Account(uid: accUid, defaultProfile: profileUid, username: username, tag: tag)
    accSrc = AccountSource(owner: accUid, provider: LocalCluster)
    localAcc = LocalAccount(uid: accUid, email: email, password: passwordHash)
    profile = Profile(uid: profileUid, owner: accUid, avatar: "", displayname: username, pronouns: "", bio: "")

  inst.db.withDb:
    try:
      db.transaction:
        db.insert(account)
        db.insert(accSrc)
        db.insert(localAcc)
        db.insert(profile)

    except RollbackError as e:
      return err(e.msg)

  ok(account)