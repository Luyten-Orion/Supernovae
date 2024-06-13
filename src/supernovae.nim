# TODO: Restructure code
# TODO: Use a logging library
import nulid
import mummy

import ./supernovae/[repositories, core, api]

var
  repo = initSQLiteRepository("supernovae.db")
  snCore = SupernovaeCore(repo: repo, idgen: initUlidGenerator())

snCore.establishAnchor()

snCore.ignite(Port(8080))