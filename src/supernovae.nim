# TODO: Restructure code
# TODO: Use a logging library
import mummy

import ./supernovae/[repositories, core, api]

var
  repo = initSQLiteRepository("supernovae.db")
  snCore = SupernovaeCore[SQLiteRepository](repo: repo)

snCore.establishAnchor()

snCore.ignite(Port(8080))