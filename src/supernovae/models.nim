import nulid
import norm/[postgres, sqlite, pragmas, model]

type
  DbVal = sqlite.DbValue | postgres.DbValue

  AccountProvider* = enum
    LocalCluster = 0'u8, ExternalCluster

  Account* = ref object of Model
    uid* {.unique, uniqueIndex: "Account_uids".}: ULID
    username* {.uniqueGroup.}: string
    tag* {.uniqueGroup.}: string
    defaultProfile*: ULID

  AccountSource* = ref object of Model
    # Account will be looked up through this
    owner* {.uniqueGroup, index: "AccountSource_owners".}: ULID
    provider* {.uniqueGroup.}: AccountProvider

  LocalAccount* = ref object of Model
    # Looked up through whatever handles the login page stuff
    uid* {.unique, uniqueIndex: "LocalAccount_uids".}: ULID # Same as `AccountSource.owner`
    email* {.unique.}: string
    password*: string # argon2 hashed password

  Profile* = ref object of Model
    uid* {.unique.}: ULID
    owner* {.index: "Profile_owners".}: ULID
    # URL? Or reference to image on CDN? Could be either, CDN is more concise, but
    # URL may be more flexible. Alternatively: Flag to indicate either.
    avatar*: string
    displayname*: string
    pronouns*: string
    bio*: string


template dbVal(s: string): DbVal =
  when DbVal is sqlite.DbValue:
    sqlite.dbValue(s)

  elif DbVal is postgres.DbValue:
    postgres.dbValue(s)

func dbType*(T: typeof ULID): string = "TEXT"
func dbValue*(val: ULID): DbVal = dbVal($val)
func to*(dbVal: DbVal, T: typeof ULID): ULID = ULID.parse(dbVal.s)