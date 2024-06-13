# TODO: Restructure code
# TODO: Use a logging library
import mummy

import ./supernovae/[repositories, core, api]
import ./supernovae/repositories/sqlite

var
  repo = initSQLiteRepository("supernovae.db")
  snCore = SupernovaeCore(repo: repo)

snCore.establishAnchor()

snCore.ignite(Port(8080))