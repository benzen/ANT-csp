csp = require 'js-csp'
_ = require 'underscore'

#----
#Config
anthill = x:0, y:0
world_dim = x: 100, y: 100
TIMEOUT_VALUE = 30
NB_ANTS_VALUE  = 10
#----------

timer = ->
  #send tick on every TIMEOUT_VALUE ms
  chan = csp.chan()
  csp.go ->
    while true
      yield csp.timeout(TIMEOUT_VALUE)
      yield csp.put(chan, 'TICK')
  chan
TIMER = csp.operations.mult(timer())

food = (x, y) ->
  id: "#{x} - #{y}"
  available: yes
  pos:
    x:y,y:y

FOODS = [
  food(10, 22),
  food(33, 67),
  food(57, 33),
  food(89, 10),
  food(5, 90)
]

world =
  snort: (pos) ->
    _.find FOODS, (f) ->
      f.available == yes and
      f.pos.x == pos.x and
      f.pos.y == pos.y

WORLD = world

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
    _.chain(generatePosition())
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
    WORLD.snort(position)

  isHomeWithFood = ->
    position.x == anthill.x and
    position.y == anthill.y and
    bag.length

  onTick = ->
    switch
      when isHomeWithFood()
        ""
      when bag.length
        goHome()
      #when onTrack()
        #followTrack()
      when onFood()
        takeHome()
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
  ctx.fillRect anthill.x, anthill.y, cellSize, cellSize

  _.each antsPositions, (antPos)->
    ctx.fillStyle = black
    ctx.fillRect antPos.x* cellSize, antPos.y * cellSize, cellSize, cellSize

  _.each FOODS, (f) ->
    if f.available
      ctx.fillStyle = red
      ctx.fillRect f.pos.x * cellSize, f.pos.y * cellSize, cellSize, cellSize

csp.go ->
  ants = _.times NB_ANTS_VALUE, ant

  statusChan = status(ants)
  while true
    statusLine = yield statusChan
    drawMap statusLine
