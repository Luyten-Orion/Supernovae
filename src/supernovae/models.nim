import nulid
import norm/[postgres, sqlite, pragmas, model]

type DbVal = sqlite.DbValue | postgres.DbValue

template dbVal(s: string): DbVal =
  when DbVal is sqlite.DbValue:
    sqlite.dbValue(s)

  elif DbVal is postgres.DbValue:
    postgres.dbValue(s)

func dbType*(T: typeof ULID): string = "TEXT"
func dbValue*(val: ULID): DbVal = dbVal($val)
func to*(dbVal: DbVal, T: typeof ULID): ULID = ULID.parse(dbVal.s)

type
  Account* = ref object of Model
    uid* {.unique.}: ULID
    username* {.uniqueGroup.}: string
    tag* {.uniqueGroup.}: string
    email* {.unique.}: string
    defaultProfile*: ULID

  Profile* = ref object of Model
    uid* {.unique.}: ULID
    owner*: ULID
    # URL? Or reference to image on CDN? Could be either, CDN is more concise, but
    # URL may be more flexible. Alternatively: Flag to indicate either.
    avatar*: string
    displayname*: string
    pronouns*: string
    bio*: string