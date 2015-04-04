csp = require 'js-csp'

#----------------------
#
# Status extractor

status = (ants) ->
  "Take each ants's positions and put it into a single channel"
  chan = csp.chan()
  csp.go ->
    while true
      positions = []
      for ant, index  in ants
        positions[index] = yield csp.take ant
      yield csp.put chan, positions
  chan

module.exports = status
