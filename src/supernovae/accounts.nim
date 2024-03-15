import nulid
import norm/[postgres, sqlite, pool]

import ./[models, core]
# TODO: Implement this.
# For now, the file will contain a skeleton of how I want the API to look like.

proc createLocallyBackedAccount(inst: SInstance, username: string, tag: string): Result[Account, string] =
  let
    accUid = inst.idgen.ulid()
    profileUid = inst.idgen.ulid()
    account = Account(uid: accUid, defaultProfile: profileUid, username: username, tag: tag)
    profile = Profile(uid: profileUid, owner: accUid, avatar: "", displayname: username, pronouns: "", bio: "")

  inst.db.withDb:
    try:
      db.transaction:
        db.insert(account)
        db.insert(profile)

    except RollbackError as e:
      return err(e.msg)

  ok(account)