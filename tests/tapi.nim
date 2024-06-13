# TODO: Finish test
import std/[unittest, json, os]

import taskpools
import puppy
import jsony
import nulid

import supernovae/[repositories, constants, core, api]
import supernovae/models/responses

var
  repo = initSQLiteRepository("supernovae.db")
  snCore = SupernovaeCore(repo: repo, idgen: initUlidGenerator())

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

  test "Account registration (Success)":
    let body = %*{
      "username": "test",
      "email": "test@test.test",
      "password": "t35t"
    }
    echo post("http://localhost:8080/api/account/register", body = $body).body

snCore.extinguish()
taskpool.shutdown()