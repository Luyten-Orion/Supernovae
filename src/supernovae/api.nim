## Defines the API routes for supernovae, gluing everything together.
## TODO: Should we split this into several submodules for different functionalities?
import std/[options, tables, times]

import nulid
import jsony
import mummy
import mummy/[
  routers
]

import ./[repositories, accounts, core]
import ./models/responses
import ./models/requests/accounts as _
import ./models/responses/accounts as _

template respond[T](request: Request, code: int, headers: HttpHeaders, body: T) =
  headers["Content-Type"] = "application/json"
  request.respond(code, headers, toJson[T](body))

proc establishAnchor*(core: SupernovaeCore) =
  ## Registers the API endpoints.
  # API Root, provides meta about the instance
  proc apiRoot(request: Request) {.gcsafe.} =
    var headers: HttpHeaders
    request.respond(200, headers, SupernovaeInstanceMeta(registrations: core.registrationStatus))

  # Account registration, creates a new account
  proc accountRegister(request: Request) {.gcsafe.} =
    var headers: HttpHeaders

    let accRegistration = try:
      let accReg = request.body.fromJson(AccountRegistrationRequest)

      if accReg.username == "" or accReg.email == "" or accReg.password == "":
        request.respond(422, headers, MissingRequiredDataError(msg: "Either the username, email or password are empty and must be filled!"))
        return

      if accReg.password.len > 128:
        request.respond(422, headers, ExcessiveDataProvidedError(msg: "The password is too long, must be 128 characters at maximum!"))
        return

      accReg
    except JsonError as e:
      request.respond(400, headers, MalformedJsonBodyError(msg: e.msg))
      return

    let ratelimit = core.ratelimiter.check("/api/account/register", 4, request.remoteAddress, initDuration(hours=1))

    if ratelimit != 0:
      request.respond(429, headers, RatelimitedError(seconds: ratelimit, msg: "Ratelimit exceeded for account registration!"))
      return

    let usernameQuery = queryIt Account:
      select 1, where it.username == accRegistration.username
    
    let emailQuery = queryIt LocalAccount:
      select 1, where it.email == accRegistration.email

    if core.repo.excavate(Account, usernameQuery).len > 0:
      request.respond(409, headers, UsernameTakenError())
      return

    if core.repo.excavate(LocalAccount, emailQuery).len > 0:
      request.respond(409, headers, EmailTakenError())
      return

    let localAcc = newLocalAccount(core.idgen.ulid, accRegistration.email, accRegistration.password)
    let acc = newAccount(localAcc.uid, accRegistration.username, AccountType.Local)
    let prf = newProfile(core.idgen.ulid, acc.uid, accRegistration.username, "")
    acc.defaultProfile = prf.uid

    if core.registrationStatus in {Gated, GatedLocal}:
      acc.flags = {AwaitingApproval}

    core.repo.deposit(localAcc)
    core.repo.deposit(acc)
    core.repo.deposit(prf)

    request.respond(201, headers, AccountCreatedSuccess())

  # Account login, authenticates an account and returns a session
  proc accountLogin(request: Request) {.gcsafe.} =
    var headers: HttpHeaders

    let accLogin = try:
      let accLogin = request.body.fromJson(AccountLoginRequest)

      if accLogin.email == "" or accLogin.password == "":
        request.respond(422, headers, MissingRequiredDataError(msg: "Either the email or password are empty and must be filled!"))
        return

      accLogin
    except JsonError as e:
      request.respond(400, headers, MalformedJsonBodyError(msg: e.msg))
      return

    let ratelimit = core.ratelimiter.check("/api/account/login", 8, request.remoteAddress, initDuration(hours=1))

    if ratelimit != 0:
      request.respond(429, headers, RatelimitedError(seconds: ratelimit, msg: "Ratelimit exceeded for account login!"))
      return

    let accountQuery = queryIt LocalAccount:
      select where it.email == accLogin.email

    let account = block:
      let acc = core.repo.excavate(LocalAccount, accountQuery)
      if acc.len == 0:
        request.respond(401, headers, InvalidCredentialsError())
        return

      if acc.len > 1:
        let uid = core.idgen.ulid()
        request.respond(500, headers, InternalError(uid: $uid))
        echo "Multiple accounts found for email '" & accLogin.email & "' Error ID: " & $uid # TODO: Replace with logger

      acc[0]

    let session = account.authenticate(core.idgen.ulid(), accLogin.password)

    if session.isNone:
      request.respond(401, headers, InvalidCredentialsError())
      return

    core.repo.deposit(session.get())

    request.respond(200, headers, AccountLoginSuccess(session: session.get().token))

  # Register the API endpoints.
  # TODO: Is '/api' unnecessary?
  core.router.get("/api", apiRoot)

  core.router.post("/api/account/register", accountRegister)
  core.router.post("/api/account/login", accountLogin)