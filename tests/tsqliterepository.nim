import std/unittest

import nulid

import supernovae/[repositories, accounts]

var
  repository: Repository

let
  accId = ULID.parse("01HTJFRZX61EH3J4NNQQ732ASB")
  profId = ULID.parse("01HTJFRZX682ECN6W18W92S5KD")

test "Initialise repository":
  repository = initSQLiteRepository("test.db")
  check repository.isUnsealed

test "Establish tables":
  repository.establish(Account)
  repository.establish(LocalAccount)
  repository.establish(Profile)

test "Deposit data":
  repository.deposit(newAccount(accId, "test_a", AccountType.Local))
  repository.deposit(newLocalAccount(accId, "test_a", "test_a"))
  repository.deposit(newProfile(profId, accId, "test_a", "test_a"))

  repository.deposit(newAccount(accId, "test_b", AccountType.Local))
  repository.deposit(newLocalAccount(accId, "test_b", "test_b"))
  repository.deposit(newProfile(profId, accId, "test_b", "test_b"))

test "Extract data":
  let query = queryIt Account:
    select 1, where it.uid == accId

  var
    accsRes = repository.excavate(Account, query)
    localRes = repository.extract(LocalAccount, accId)
    profsRes = repository.extract(Profile, profId)
  
  check accsRes.len == 1
  check localRes.len == 1
  check profsRes.len == 1

  check accsRes[0].uid == accId
  check localRes[0].uid == accId
  check profsRes[0].uid == profId

  check accsRes[0].typ == AccountType.Local

  check accsRes[0].username == "test_b"
  check localRes[0].email == "test_b"
  check localRes[0].verify("test_b")
  check profsRes[0].displayname == "test_b"
  check profsRes[0].bio == "test_b"


repository.seal()