csp = require 'js-csp'
config = require './config'
#----------
#Timer
timer = ->
  "send tick on every IMEOUT_VALUE ms"
  chan = csp.chan()
  csp.go ->
    while true
      yield csp.timeout(config.TIMEOUT_VALUE)
      yield csp.put(chan, 'TICK')
  chan
module.exports = csp.operations.mult(timer())

