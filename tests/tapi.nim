# TODO: Finish test
import std/[strutils, unittest, json, os]

import taskpools
import puppy
import jsony
import nulid

import supernovae/[repositories, constants, core, api]
import supernovae/models/responses
import supernovae/models/responses/accounts

removeFile("test.db")

var
  repo = initSQLiteRepository("test.db")
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

suite "API - Misc":
  test "API Root":
    check get("http://localhost:8080/api").body.fromJson(SupernovaeInstanceMeta) == SupernovaeInstanceMeta(
      registrations: snCore.registrationStatus, version: SNVersion)

when not defined(snTestSkipApiAccReg):
  suite "API - Account Registration":
    test "Account Registration (Success)":
      let body = %*{
        "username": "test.username",
        "email": "test@test.test",
        "password": "t35t"
      }
      check post("http://localhost:8080/api/account/register", body = $body).body
        .fromJson(SupernovaeSuccess).success == "Account Created"

    test "Account Registration (Failure - Username Taken)":
      let body = %*{
        "username": "test.username",
        "email": "test@test.test.unused",
        "password": "t35t"
      }
      check post("http://localhost:8080/api/account/register", body = $body).body
        .fromJson(SupernovaeError).error == "Username Taken"

    test "Account Registration (Failure - Email Taken)":
      let body = %*{
        "username": "test.username.unused",
        "email": "test@test.test",
        "password": "t35t"
      }
      check post("http://localhost:8080/api/account/register", body = $body).body
        .fromJson(SupernovaeError).error == "Email Taken"

    test "Account Registration (Failure - Excessive Data Provided)":
      let body = %*{
        "username": "test.username.unused",
        "email": "test@test.test.unused",
        "password": repeat("a", 129)
      }
      check post("http://localhost:8080/api/account/register", body = $body).body
        .fromJson(SupernovaeError).error == "Excessive Data Provided"

    test "Account Registration (Success - 4th Request)":
      let body = %*{
        "username": "test.username.unused",
        "email": "test@test.test.unused",
        "password": "t35t"
      }
      check post("http://localhost:8080/api/account/register", body = $body).body
        .fromJson(SupernovaeSuccess).success == "Account Created"

    test "Account Registration (Failure - Ratelimit Exceeded)":
      let body = %*{
        "username": "test.username.unused",
        "email": "test@test.test.unused",
        "password": "t35t"
      }
      check post("http://localhost:8080/api/account/register", body = $body).body
        .fromJson(SupernovaeError).error == "Ratelimited"

    test "Account Registration (Failure - Malformed JSON Body)":
      check post("http://localhost:8080/api/account/register", body = "womp").body
        .fromJson(SupernovaeError).error == "Malformed JSON Body"

    test "Account Registration (Failure - Missing Required Data)":
      let body = %*{
        "email": "test@test.test.unused",
        "password": "t35t"
      }
      check post("http://localhost:8080/api/account/register", body = $body).body
        .fromJson(SupernovaeError).error == "Missing Required Data"
else:
  discard post("http://localhost:8080/api/account/register", body = `$` %*{
    "username": "test.username",
    "email": "test@test.test",
    "password": "t35t"
  })


when not defined(snTestSkipApiAccLogin):
  suite "API - Account Login":
    test "Account Login (Success)":
      let body = %*{
        "email": "test@test.test",
        "password": "t35t"
      }
      check post("http://localhost:8080/api/account/login", body = $body).body
        .fromJson(SupernovaeSuccess).success == "Account Logged In"

    test "Account Login (Failure - Invalid Password)":
      let body = %*{
        "email": "test@test.test",
        "password": "t00t"
      }
      check post("http://localhost:8080/api/account/login", body = $body).body
        .fromJson(SupernovaeError).error == "Invalid Credentials"

    test "Account Login (Failure - Invalid Email)":
      let body = %*{
        "email": "test@test.test",
        "password": "t00t"
      }
      check post("http://localhost:8080/api/account/login", body = $body).body
        .fromJson(SupernovaeError).error == "Invalid Credentials"

    test "Account Login (Failure - Ratelimit Exceeded)":
      let body = %*{
        "email": "test@test.test",
        "password": "t00t"
      }
      for i in 2..7:
        discard post("http://localhost:8080/api/account/login", body = $body)

      check post("http://localhost:8080/api/account/login", body = $body).body
        .fromJson(SupernovaeError).error == "Ratelimited"

snCore.extinguish()
taskpool.shutdown()