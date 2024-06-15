import std/unittest

import supernovae/[repositories, accounts]

test "Building a query":
  var query = queryIt Account:
    select where "test" == it.username

  echo $query