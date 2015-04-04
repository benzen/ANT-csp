
csp = require 'js-csp'
_ = require 'underscore'

ant = require './lib/ant'
FOOD = require './lib/food'
config = require './lib/config'
status = require './lib/status'
drawMap = require './lib/render'
#----------
#
#Main loop
ants = _.times config.NB_ANTS_VALUE, ant

statusChan = status(ants)

csp.go ->
  while true
    statusLine = yield statusChan
    drawMap statusLine

