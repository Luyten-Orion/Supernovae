# TODO: Finish test
import unittest

import taskpools
import puppy

import supernovae/[repositories, core]

let
  repo = initSQLiteRepository("supernovae.db")
  snCore = SupernovaeCore[SQLiteRepository](repo: repo)



suite "API":
  discard