import std/unittest

import nulid

import supernovae/[repositories, accounts]

var
  repository: SQLiteRepository
  accs, local, profs: MineHandle[SQLiteRepository]

let
  accId = ulid()
  profId = ulid()

test "Initialise repository":
  repository = initSQLiteRepository("test.db")
  check repository.isOpen

test "Establish tables":
  accs = repository.establish(Account, "accounts")
  local = repository.establish(LocalAccount, "local_accounts")
  profs = repository.establish(Profile, "profiles")

test "Deposit data":
  accs.deposit(newAccount(accId, "test_a", AccountType.Local))
  local.deposit(newLocalAccount(accId, "test_a", "test_a"))
  profs.deposit(newProfile(profId, accId, "test_a", "test_a"))

  accs.deposit(newAccount(accId, "test_b", AccountType.Local))
  local.deposit(newLocalAccount(accId, "test_b", "test_b"))
  profs.deposit(newProfile(profId, accId, "test_b", "test_b"))

test "Extract data":
  var
    accsRes = accs.extract(Account, accId)
    localRes = local.extract(LocalAccount, accId)
    profsRes = profs.extract(Profile, profId)
  
  check accsRes.len == 1
  check localRes.len == 1
  check profsRes.len == 1

  check accsRes[0].uid == accId
  check localRes[0].uid == accId
  check profsRes[0].uid == accId

  check accsRes[0].typ == AccountType.Local

  check accsRes[0].username == "test_b"
  check localRes[0].email == "test_b"
  check localRes[0].password == "test_b"
  check profsRes[0].displayname == "test_b"
  check profsRes[0].bio == "test_b"


repository.close()