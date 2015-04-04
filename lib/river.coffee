_ = require 'underscore'
config = require './config'
utils = require './utils'
#River
#-------------
generateRiver = (start, length)->
  river = []
  generateRiverRec = (start, acc) ->
    if acc.length == length then return acc
    np = _.chain utils.contigous(start)
      .filter utils.isInWorldBounds
      .shuffle()
      .first()
      .value()
    acc.push np
    generateRiverRec(np, acc)
  generateRiverRec(start, river)
  river
RIVER = generateRiver x:0,y:0, 2000

module.exports =
  RIVER: RIVER
