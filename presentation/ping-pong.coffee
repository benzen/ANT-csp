csp = require 'js-csp'
player = (name, table) ->
  csp.go ->
    while true 
      ball = yield csp.take table
      ball.hits++
      console.log name, ball.hits
      yield csp.timeout(100)
      yield csp.put table, ball

table = csp.chan()

player "ping", table
player "pong", table

csp.putAsync table, hits: 0
