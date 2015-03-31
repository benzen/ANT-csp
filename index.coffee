csp = require 'js-csp'
_ = require 'underscore'

#----
#Config
anthill = x:0, y:0
world_dim = x: 100, y: 100
TIMEOUT_VALUE = 10
NB_ANTS_VALUE  = 50
#----------

#Timer
timer = ->
  #send tick on every TIMEOUT_VALUE ms
  chan = csp.chan()
  csp.go ->
    while true
      yield csp.timeout(TIMEOUT_VALUE)
      yield csp.put(chan, 'TICK')
  chan
TIMER = csp.operations.mult(timer())
#-----------
#
#Food
food = (x, y) ->
  amount: 10
  pos:
    x:x,y:y

FOODS = [
  food(10, 22),
  food(33, 67),
  food(57, 33),
  food(89, 10),
  food(5, 90),
  food(10,10),
  food(22, 4)
]
isSamePos = (p1,p2) ->
  p1.x == p2.x and p1.y == p2.y

isThereFood = (pos) ->
  _.find FOODS, (f) ->
    f.amount > 0 and
    isSamePos f.pos, pos
#----------
#
#Marks
MARKS = []
snort = (p) ->
  _.filter MARKS, (m) ->
    m.level > 0 and
    isSamePos(m.from, p)

mark = (from, to) ->
  previousMark = _.find MARKS, (m)->
    isSamePos(m.from, from) and
    isSamePos(m.to, to)
  if previousMark
    previousMark.level++
  else
    MARKS.push
      from: from
      to: to
      level: 1

evaporation = ->
  localTimer = csp.chan()
  csp.operations.mult.tap(TIMER, localTimer)
  csp.go ->
    counter = 0
    while true
      yield csp.take localTimer
      counter++
      if counter == 1000
        counter = 0
        _.each MARKS, (m)->
          m.level--
        #Garbage collecting marks
        MARKS = _.filter MARKS, (m)->
          m.level < 0
#---------
#
#Ants
ant = ->
  position = x:anthill.x, y:anthill.y
  previous_position = x:anthill.x, y:anthill.y
  bag = []

  generatePosition = ->
    [   x:position.x+1, y:position.y
      ,
        x:position.x-1, y:position.y
      ,
        x:position.x, y:position.y+1
      ,
        x:position.x, y:position.y-1
    ]

  isValidPosition = (p) ->
    p.x >= 0 and
    p.y >= 0 and
    p.x <= world_dim.x and
    p.y <= world_dim.y
  isNotPreviousPosition = (p) ->
    not isSamePos(p, previous_position)

  distance = (p1, p2) ->
    x = Math.pow(p2.x - p1.x, 2)
    y = Math.pow(p2.y - p1.y, 2)
    Math.sqrt(x+y)

  nextPos = ->
    #choose a random new (valid) position
    _.chain(generatePosition())
      .filter isValidPosition
      .filter isNotPreviousPosition
      .shuffle()
      .sortBy isThereFood
      .first()
      .value()

  move_to = (p)->
    [previous_position, position] = [position, p]

  onTrack = ->
    snort position

  followTrack = ->
    followedMark  = _.chain snort(position)
      .filter (m) -> isNotPreviousPosition(m.to)
      .last()
      .value()
    if followedMark
      move_to followedMark.to
    else
      keepSearching()

  nextPosToHome = ->
    # choose a position that make me closer to anthill
    positions = generatePosition()
    _.chain(positions)
      .filter isValidPosition
      .sortBy (p) ->distance anthill, p
      .first()
      .value()

  goHome = ->
    if bag.length
      mark position, previous_position
    move_to nextPosToHome()

  takeHome = ->
    f = isThereFood(position)
    f.amount--
    bag = [f]
    goHome()

  onFood = ->
    !!isThereFood(position)

  isHomeWithFood = ->
    bag.length and
    isSamePos position, anthill

  keepSearching = ->
    move_to nextPos()

  onTick = ->
    switch
      when isHomeWithFood()
        ""
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
      yield csp.put chan, position
      yield csp.take(localTimer)
      onTick()
  chan
#----------------------
#
# Status extractor

status = (ants) ->
  chan = csp.chan()
  csp.go ->
    while true
      positions = []
      for ant, index  in ants
        positions[index] = yield csp.take ant
      yield csp.put chan, positions
  chan


#----------------------
#
# Rendering

$ = require 'jquery'
cellSize = 10
scale = (coord) -> cellSize * coord
width = scale world_dim.x
height = scale world_dim.y
black = 'black'
green = 'green'
brown = 'brown'
red   = 'red'
blue = 250

getContext = (mapWidth, mapHeight) ->
  unless $('canvas').length
    canvas = $('<canvas>')
    .attr("width", width)
    .attr("height", height)
    .appendTo('body')

  $('canvas')[0].getContext("2d")

drawMap = (antsPositions) ->
  ctx = getContext()
  ctx.fillStyle = 'green'
  ctx.fillRect 0, 0, scale(world_dim.x), scale(world_dim.y)

  _.each MARKS, (m)->
    if m.level > 0
      ctx.fillStyle = "rgba(170,255, 234, #{m.level/100})"
      ctx.fillRect scale(m.from.x), scale(m.from.y), cellSize, cellSize

  ctx.fillStyle = brown
  ctx.fillRect anthill.x, anthill.y, cellSize, cellSize

  _.each antsPositions, (antPos)->
    ctx.fillStyle = black
    ctx.fillRect scale(antPos.x), scale(antPos.y), cellSize, cellSize

  _.each FOODS, (f) ->
    if f.amount > 0
      ctx.fillStyle = red
      ctx.fillRect scale(f.pos.x), scale(f.pos.y), cellSize, cellSize
#----------
#
#Main loop
ants = _.times NB_ANTS_VALUE, ant
evaporation()
statusChan = status(ants)

csp.go ->
  while true
    statusLine = yield statusChan
    drawMap statusLine

