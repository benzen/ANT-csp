csp = require 'js-csp'
_ = require 'underscore'

anthill = x:15, y:21
world_dim = x: 100, y: 100
TIMEOUT = 10

timer = ->
  #send tick on every X s
  chan = csp.chan()
  csp.go ->
    while true
      t = csp.timeout(TIMEOUT)
      res = yield csp.alts([chan, t])
      yield csp.put(chan, 'TICK')
  chan
TIMER = timer()

food = (x, y) ->
  id: "#{x} - #{y}"
  available: yes
  pos:
    x:y,y:y

foods = [
  food(10, 22),
  food(33, 67),
  food(57, 33),
  food(89, 10),
  food(5, 90)
]

world =
  snort: (pos) ->
    _.find foods, (f) ->
      f.available == yes and
      f.pos.x == pos.x and
      f.pos.y == pos.y

ant = ->
  position = x:0, y:0
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

  distance = (p1, p2) ->
    x = Math.pow(p2.x - p1.x, 2)
    y = Math.pow(p2.y - p1.y, 2)
    Math.sqrt(x+y)

  nextPos = ->
    #choose a random new (valid) position
    positions = generatePosition()
    _.chain(positions)
      .filter(isValidPosition)
      .shuffle()
      .first()
      .value()

  nextPosToHome = ->
    # choose a position that make me closer to anthill
    positions = generatePosition()
    _.chain(positions)
      .filter(isValidPosition)
      .sortBy((p) ->distance(x:0, y:0, p))
      .first()
      .value()

  #nextPosFollowingPath
  #followPath: ->

  goHome = ->
    p = nextPosToHome()
    position = p

  takeHome = ->
    f = world.snort(position)
    f.available = no
    bag = [f]
    goHome()

  keepSearching = ->
    position = nextPos()

  onFood = ->
    world.snort(position)

  isHomeWithFood = ->
    position.x == 0 and
    position.y == 0 and
    bag.length

  onTick = ->
    if isHomeWithFood()
    else if bag.length
      goHome()
    #else if onTrack()
    # followTrack
    else if onFood()
      takeHome()
    else
      keepSearching()

  chan =  csp.chan()
  csp.go ->
    while true
      yield csp.put chan, position
      yield csp.take(TIMER)
      onTick()
  chan
#----------------------
# Status extractor

status = (ants) ->
  chan = csp.chan()
  csp.go ->
    while true
      a1p = yield ants[0]
      a2p = yield ants[1]
      a3p = yield ants[2]
      positions  = [a1p, a2p, a3p]
      yield csp.put chan, positions
  chan

ants = [ant(), ant(), ant()]

#----------------------
# Présentation

$ = require 'jquery'
cellSize = 10
width = world_dim.x * cellSize
height = world_dim.y * cellSize
black = 'black'
green = 'green'
brown = 'brown'
red   = 'red'

getContext = (mapWidth, mapHeight) ->
  unless $('canvas').length
    canvas = $('<canvas>')
    .attr("width", width)
    .attr("height", height)
    .appendTo('body')

  $('canvas')[0].getContext("2d")

drawMap = (antsPositions) ->
  ctx = getContext()
  ctx.fillStyle = green
  ctx.fillRect 0, 0, width, height

  ctx.fillStyle = brown
  ctx.fillRect 0, 0, cellSize, cellSize

  _.each antsPositions, (antPos)->
    ctx.fillStyle = black
    ctx.fillRect antPos.x* cellSize, antPos.y * cellSize, cellSize, cellSize

  _.each foods, (f)->
    if f.available
      ctx.fillStyle = red
      ctx.fillRect f.pos.x * cellSize, f.pos.y * cellSize, cellSize, cellSize

csp.go ->
  statusChan = status(ants)
  while true
    statusLine = yield statusChan
    drawMap statusLine
