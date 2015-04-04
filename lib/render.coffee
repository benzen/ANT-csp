$ = require 'jquery'
_ = require 'underscore'
config = require './config'
marks = require './marks'
river = require './river'
food = require './food'

#----------------------
#
# Rendering

cellSize = 10
scale = (coord) -> cellSize * coord
width = scale config.world_dim.x
height = scale config.world_dim.y
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

direction = (p1, p2) ->
  x: (p1.x - p2.x), y:(p1.y-p2.y)

deg_to_rad = (deg) ->
  deg * Math.PI/180

direction_to_rad = ({x, y})->
  switch
    when x is -1 and y is -1 then deg_to_rad(-135)
    when x is -1 and y is  0 then deg_to_rad(-90)
    when x is -1 and y is  1 then deg_to_rad(-45)
    when x is  0 and y is -1 then deg_to_rad(180)
    when x is  0 and y is  0 then deg_to_rad(0)
    when x is  0 and y is  1 then deg_to_rad(0)
    when x is  1 and y is -1 then deg_to_rad(135)
    when x is  1 and y is  0 then deg_to_rad(90)
    when x is  1 and y is  1 then deg_to_rad(45)

drawMap = (antsPositions) ->
  "Draw everything; background, marks, anthill, ants, foods"
  ctx = getContext()
  ctx.fillStyle = 'green'
  ctx.fillRect 0, 0, scale(config.world_dim.x), scale(config.world_dim.y)

  _.each marks.MARKS, (m)->
    ctx.fillStyle = "rgba(170,255, 234, #{m.level/1000})"
    ctx.fillRect scale(m.from.x), scale(m.from.y), cellSize, cellSize

  ctx.fillStyle = brown
  ctx.fillRect scale(config.anthill.x), scale(config.anthill.y), cellSize, cellSize

  _.each antsPositions, ({position, previous_position})->
    dir = direction(position, previous_position)
    angle = direction_to_rad dir
    img = new Image()
    img.src = "fourmi.svg"

    ctx.save()
    trX = scale(position.x) + cellSize
    trY = scale(position.y) + cellSize
    ctx.translate(trX, trY)
    ctx.rotate(angle)
    ctx.translate(-trX, -trY)

    ctx.drawImage img, scale(position.x), scale(position.y), cellSize*2, cellSize*2
    
    ctx.restore()
    
  _.each food.FOODS, (f) ->
    if f.amount > 0
      ctx.fillStyle = red
      ctx.fillRect scale(f.pos.x), scale(f.pos.y), cellSize, cellSize

  _.each river.RIVER, (r) ->
    ctx.fillStyle = "blue"
    ctx.fillRect scale(r.x), scale(r.y), cellSize, cellSize

module.exports = drawMap
