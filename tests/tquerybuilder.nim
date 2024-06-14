import std/unittest

import supernovae/[repositories, accounts]

test "Building a query":
  var query = queryIt Account:
    select 1, where it.username == "test"

  echo query.repr