import std/unittest

import nulid

import supernovae/accounts

test "Accounts":
  var
    acc = newAccount(ulid(), "test", AccountType.Local)
    localAcc = newLocalAccount(acc.uid, "this.is@a.test", "test")
    prof = newProfile(ulid(), acc.uid, "Test Account", "A test account.")

  acc.defaultProfile = prof.uid