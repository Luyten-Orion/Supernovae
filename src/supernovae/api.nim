## Defines the API routes for supernovae, gluing everything together.
## TODO: Should we split this into several submodules for different functionalities?
import std/times

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
  request.respond(code, headers, toJson[T](body))

proc establishAnchor*(core: SupernovaeCore) =
  ## Registers the API endpoints.
  proc apiRoot(request: Request) {.gcsafe.} =
    var headers: HttpHeaders
    headers["Content-Type"] = "application/json"
    request.respond(200, headers, SupernovaeInstanceMeta(registrations: core.registrationStatus))

  proc registerAccount(request: Request) {.gcsafe.} =
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

    let localAcc = newLocalAccount(core.idgen.ulid, accRegistration.email, accRegistration.password)
    let acc = newAccount(localAcc.uid, accRegistration.username, AccountType.Local)
    let prf = newProfile(core.idgen.ulid, acc.uid, accRegistration.username, "")
    acc.defaultProfile = prf.uid

    if core.registrationStatus in {Gated, GatedLocal}:
      acc.flags = {AwaitingApproval}

    core.repo.deposit(localAcc)
    core.repo.deposit(acc)
    core.repo.deposit(prf)

    request.respond(201, headers, AccountCreatedResponse())

  # Register the API endpoints.
  # TODO: Is '/api' unnecessary?
  core.router.get("/api", apiRoot)

  core.router.post("/api/account/register", registerAccount)
