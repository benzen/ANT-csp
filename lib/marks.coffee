_ = require 'underscore'
csp = require 'js-csp'
utils = require './utils'
TIMER = require './timer'
config = require './config'
#----------
#
#Marks
MARKS = []

snort = (p) ->
  "is there a mark starting at the given position with a level superior to 0"
  _.filter MARKS, (m) ->
    m.level > 0 and
    utils.isSamePos(m.from, p)

mark = (from, to) ->
  "create a directed mark, if it already exists increase it's level"
  previousMark = _.find MARKS, (m)->
    utils.isSamePos(m.from, from) and
    utils.isSamePos(m.to, to)
  if previousMark
    previousMark.level += config.MARKS_LEVEL_INCREMENT
  else
    MARKS.push
      from: from
      to: to
      level: config.MARKS_LEVEL_INCREMENT

isThereMark = (pos) ->
  _.find MARKS, (m) ->
    m.level > 0 and
    utils.isSamePos m.from, pos

evaporation = ->
  "Evaporation process"
  localTimer = csp.chan()
  csp.operations.mult.tap(TIMER, localTimer)
  csp.go ->
    counter = 0
    while true
      yield csp.take localTimer
      counter++
      if counter == 10
        counter = 0
        _.each MARKS, (m)->
          m.level -= config.MARKS_LEVEL_DECREMENT

evaporation()

module.exports =
  MARKS: MARKS
  isThereMark: isThereMark
  snort:snort
  mark:mark
