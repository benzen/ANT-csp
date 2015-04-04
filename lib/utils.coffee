config =  require './config'

contigous = (position)->
  [   x:position.x+1, y:position.y
    ,
      x:position.x-1, y:position.y
    ,
      x:position.x, y:position.y+1
    ,
      x:position.x, y:position.y-1
  ]
isInWorldBounds = (p) ->
  p.x >= 0 and
  p.y >= 0 and
  p.x <= config.world_dim.x and
  p.y <= config.world_dim.y

isSamePos = (p1,p2) ->
  "Compare two positions"
  p1.x == p2.x and p1.y == p2.y

module.exports = 
  contigous:contigous
  isInWorldBounds:isInWorldBounds
  isSamePos:isSamePos
