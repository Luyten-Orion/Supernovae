# TODO: Finish test
import std/[unittest, os]

import taskpools
import puppy
import jsony

import supernovae/[repositories, constants, core, api]
import supernovae/models/responses

var
  repo = initSQLiteRepository("supernovae.db")
  snCore = SupernovaeCore[SQLiteRepository](repo: repo)

snCore.establishAnchor()

proc startServer() =
  try:
    {.gcsafe.}:
      snCore.ignite(Port(8080))
  except Exception as e:
    echo e.msg

var
  taskpool = Taskpool.new()

taskpool.spawn(startServer())

# `server.waitUntilReady` causes SIGILL
# Sleep to ensure server has loaded
sleep(1000)

suite "API":
  test "API Root":
    check get("http://localhost:8080/api").body.fromJson(SupernovaeInstanceMeta) == SupernovaeInstanceMeta(
      registrations: snCore.registrationStatus, version: SNVersion)

snCore.extinguish()
taskpool.shutdown()