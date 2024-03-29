import std/[strformat, unittest, options]

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

  check verifyToken(se, se.token) == SessionState.Active # Valid token
  check verifyToken(se, "not-a-token") == SessionState.Invalid # Not a token
  check verifyToken(se, &"{ULID()}.{se.uid}.{se.timestamp}") == SessionState.IncorrectUser # Invalid user
  check verifyToken(se, &"{se.owner}.{ULID()}.{se.timestamp}") == SessionState.Invalid # Invalid user
  check verifyToken(se, &"{se.owner}.{se.uid}.0") == SessionState.Expired # Expired token