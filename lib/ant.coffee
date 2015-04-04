config = require './config'
csp = require 'js-csp'
TIMER = require './timer'
utils = require './utils'
food = require './food'
marks = require './marks'
river = require './river'
_ = require 'underscore'
#---------
#
#Ants
ant = ->
  "Ant process"
  position = x:config.anthill.x, y:config.anthill.y
  previous_position = x:config.anthill.x, y:config.anthill.y #usefull to not going backward
  bag = []

  generatePosition = ->
    "create possible moves"
    [   x:position.x+1, y:position.y
      ,
        x:position.x-1, y:position.y
      ,
        x:position.x, y:position.y+1
      ,
        x:position.x, y:position.y-1
      ,
        x:position.x-1, y:position.y-1
      ,
        x:position.x+1, y:position.y+1
    ]

  isValidPosition = (p) ->
    "Assert that the given position respect the bounds of the known world"
    utils.isInWorldBounds(p) and
    not _.any river.RIVER, (cp) -> utils.isSamePos p, cp

  isNotPreviousPosition = (p) ->
    not utils.isSamePos(p, previous_position)

  distance = (p1, p2) ->
    "compute the distance between the two given points"
    x = Math.pow(p2.x - p1.x, 2)
    y = Math.pow(p2.y - p1.y, 2)
    Math.sqrt(x+y)

  nextPos = ->
    "choose a random new (valid) position, as close as possible from food"
    _.chain(generatePosition())
      .filter isValidPosition
      .filter isNotPreviousPosition
      .shuffle()
      .sortBy (p) -> food.isThereFood(p) 
      .first()
      .value()

  move_to = (p)->
    "make the current position the previous_position, and the given position the current position"
    unless p then p = previous_position
    [previous_position, position] = [position, p]

  onTrack = ->
    "is there a mark on my current Position"
    not _.isEmpty  marks.snort  position

  followTrack = ->
    "go to the other end of the mark. If it's the end of the track find a random position."
    followedMark  = _.chain marks.snort(position)
      .filter (m) -> isNotPreviousPosition(m.to)
      .filter (m) -> m.level%2
      .first()
      .value()
    if followedMark
      move_to followedMark.to
    else
      keepSearching()
  
  nextPosToHome = ->
    "find a position that go closer to the anthill"
    _.chain(generatePosition())
      .filter isValidPosition
      .filter isNotPreviousPosition
      .sortBy (p) -> distance( config.anthill, p)
      .first(3)
      .shuffle()
      .first()
      .value()

  goHome = ->
    "move to a position closer to anthill and put a mark"
    marks.mark position, previous_position
    move_to nextPosToHome()

  takeHome = ->
    "take the food on the floor(reduce it's amount and put it into my bag) and go to the anthill."
    f = food.isThereFood(position)
    f.amount--
    bag = [f]
    goHome()

  onFood = ->
    "Is there food on this position"
    !!food.isThereFood(position)

  isHomeWithFood = ->
    "What's on tv?"
    bag.length and
    utils.isSamePos position, config.anthill

  keepSearching = ->
    "Choose a new random position"
    move_to nextPos()

  onTick = ->
    "What to do when Timer's tick"
    switch
      when isHomeWithFood()
        bag.pop()
        move_to nextPos()
      when bag.length
        goHome()
      when onFood()
        takeHome()
      when onTrack()
        followTrack()
      else
        keepSearching()

  chan =  csp.chan()
  csp.go ->
    localTimer = csp.chan()
    csp.operations.mult.tap(TIMER, localTimer)
    while true
      yield csp.put chan, position:position, previous_position: previous_position
      yield csp.take(localTimer)
      onTick()
  chan

module.exports = ant
