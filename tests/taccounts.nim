import std/[unittest, options]

import nulid

import supernovae/accounts

test "Accounts":
  var
    acc = newAccount(ulid(), "test", AccountType.Local)
    localAcc = newLocalAccount(acc.uid, "this.is@a.test", "test")
    prof = newProfile(ulid(), acc.uid, "Test Account", "A test account.")

  acc.defaultProfile = prof.uid

  var s = localAcc.authenticate(ulid(), "test")

  assert s.isSome, "Account authentication failed."

  var se = s.get()

  check verifyToken(se, se.token) == SessionState.Active
  check verifyToken(se, "invalid") == SessionState.Invalid
  check verifyToken(Session(uid: se.uid, timestamp: 0), se.token) == SessionState.Expired