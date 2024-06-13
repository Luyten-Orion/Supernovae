## Implements the base logic for the repository.
## TODO: PostgreSQL/other database provider implementation, likely requires me to learn and implementing pooling.
##
## TODO: Figure out pooling for databases.
##
## TODO: Maybe a small SQL statement builder to reduce the amount of string operations done? Example from Debby
## https://github.com/treeform/debby/blob/4ad7f6ecf60ed125672ec8ffa44becfd9c8dbb46/src/debby/common.nim#L260-L313
## We do need to make it so it can be used for multiple types of databases though...

type
  Repository* = ref object of RootObj
    isUnsealedImpl*: (proc(r: Repository): bool)
    sealImpl*: (proc(r: Repository))
    establishImpl*: (proc(r: Repository, obj: typedesc[ref object], mine: string))
    depositImpl*: (proc(r: Repository, obj: ref object))
    extractImpl*: (proc(r: Repository, obj: typedesc[ref object], idx: ref object, limit: Natural = 0): seq[ref object])

# ? How these are handled is up to the repository implementation
# TODO: Foreign keys, multi-column constraint/indexes
template primary*() {.pragma.}
template unique*() {.pragma.}
template index*() {.pragma.}
template uniqueIndex*() {.pragma.}

# ? At compile-time, these calls redirect to the corresponding implementation.
# TODO: Wrap errors into enum/`Result`s instead of relying on exceptions for cleaner code.
# TODO: Inline?
proc isUnsealed*(provider: Repository): bool = provider.isUnsealedImpl(provider)
proc seal*(provider: Repository) = provider.sealImpl(provider)

proc establish*[U: ref object](provider: Repository, obj: typedesc[U], mine: string) =
  ## Establishes a table using an object to define the needed tables
  provider.establishImpl(provider, obj, mine)

proc deposit*[U: ref object](provider: Repository, obj: U) =
  ## Deposits an object into a database using the corrosponding `depositImpl`
  provider.depositImpl(provider, obj)

proc extract*[U: ref object | object, V](provider: Repository, obj: typedesc[V],
  idx: U, limit: Natural = 0): seq[V] =
  ## Extracts an object from a database using the corrosponding `extractImpl`
  result = provider.extractImpl(provider, obj, idx, limit)
