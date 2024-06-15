## Defines the the models used for responses from the server.
## TODO: Split this into several submodules for different functionalities?
import std/strutils

import ../constants

type
  SupernovaeRegistationsStatus* = enum
    ## The user registration status of the supernovae instance.
    Open, Gated, GatedLocal, GatedExternal, Closed

  SupernovaeInstanceMeta* = object
    ## The metadata for the supernovae instance, used for the root API response.
    displayname*: string = "Unnamed Supernovae"
    version*: string = SNVersion
    registrations*: SupernovaeRegistationsStatus

  SupernovaeSuccess* = object
    success*, msg*: string

  SupernovaeError* = object
    error*, msg*: string

  InternalError* = object
    error*: string = "Internal Error"
    uid*: string # Unique ID for error to allow easy tracking
    msg*: string

  MalformedJsonBodyError* = object
    error*: string = "Malformed JSON Body"
    msg*: string

  MissingRequiredDataError* = object
    error*: string = "Missing Required Data"
    msg*: string

  ExcessiveDataProvidedError* = object
    error*: string = "Excessive Data Provided"
    msg*: string

  RatelimitedError* = object
    error*: string = "Ratelimited"
    seconds*: int64
    msg*: string