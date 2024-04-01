import std/unittest

import supernovae/[storage_provider, accounts]

var provider: SQLiteProvider
var accs, local, profs: MineHandle[SQLiteProvider]

test "Initialise provider":
  provider = initSQLiteProvider("test.db")
  check provider.isOpen

test "Establish tables":
  accs = provider.establish(Account, "accounts")
  local = provider.establish(LocalAccount, "local_accounts")
  profs = provider.establish(Profile, "profiles")

provider.close()