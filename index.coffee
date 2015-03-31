csp = require 'js-csp'
_ = require 'underscore'

#----
#Config
anthill = x:40, y:40
world_dim = x: 100, y: 100
TIMEOUT_VALUE = 33
NB_ANTS_VALUE  = 100
#----------

#Timer
timer = ->
  "send tick on every IMEOUT_VALUE ms"
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
  "Create a food at the given position, every food as an amount of 10"
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
  "Compare two positions"
  p1.x == p2.x and p1.y == p2.y

isThereFood = (pos) ->
  "find a food (with amount superior to 0) at the given position"
  _.find FOODS, (f) ->
    f.amount > 0 and
    isSamePos f.pos, pos
#----------
#
#Marks
MARKS = []
snort = (p) ->
  "is there a mark starting at the given position with a level superior to 0"
  _.filter MARKS, (m) ->
    m.level > 0 and
    isSamePos(m.from, p)

mark = (from, to) ->
  "create a directed mark, if it already exists increase it's level"
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
  "Evaporation process"
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
  "Ant process"
  position = x:anthill.x, y:anthill.y
  previous_position = x:anthill.x, y:anthill.y #usefull to not going backward
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
    p.x >= 0 and
    p.y >= 0 and
    p.x <= world_dim.x and
    p.y <= world_dim.y
  isNotPreviousPosition = (p) ->
    not isSamePos(p, previous_position)

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
      .sortBy isThereFood
      .first()
      .value()

  move_to = (p)->
    "make the current position the previous_position, and the given position the current position"
    [previous_position, position] = [position, p]

  onTrack = ->
    "is there a mark on my current Position"
    snort position

  followTrack = ->
    "go to the other end of the mark. If it's the end of the track find a random position."
    followedMark  = _.chain snort(position)
      .filter (m) -> isNotPreviousPosition(m.to)
      .last()
      .value()
    if followedMark
      move_to followedMark.to
    else
      keepSearching()

  nextPosToHome = ->
    "find a position that go closer to the anthill"
    positions = generatePosition()
    _.chain(positions)
      .filter isValidPosition
      .sortBy (p) ->distance anthill, p
      .first()
      .value()

  goHome = ->
    "move to a position closer to anthill and put a mark"
    mark position, previous_position
    move_to nextPosToHome()

  takeHome = ->
    "take the food on the floor(reduce it's amount and put it into my bag) and go to the anthill."
    f = isThereFood(position)
    f.amount--
    bag = [f]
    goHome()

  onFood = ->
    "Is there food on this position"
    !!isThereFood(position)

  isHomeWithFood = ->
    "What's on tv?"
    bag.length and
    isSamePos position, anthill

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
      yield csp.put chan, position
      yield csp.take(localTimer)
      onTick()
  chan
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
  "return the first canvas's 2d context, create one if there isn't one"
  unless $('canvas').length
    canvas = $('<canvas>')
    .attr("width", width)
    .attr("height", height)
    .appendTo('body')

  $('canvas')[0].getContext("2d")

drawMap = (antsPositions) ->
  "Draw everything; background, marks, anthill, ants, foods"
  ctx = getContext()
  ctx.fillStyle = 'green'
  ctx.fillRect 0, 0, scale(world_dim.x), scale(world_dim.y)

  _.each MARKS, (m)->
    ctx.fillStyle = "rgba(170,255, 234, #{m.level/100})"
    ctx.fillRect scale(m.from.x), scale(m.from.y), cellSize, cellSize

  ctx.fillStyle = brown
  ctx.fillRect scale(anthill.x), scale(anthill.y), cellSize, cellSize

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

