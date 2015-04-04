config = require './config'
utils = require './utils'
_ = require 'underscore'

#-----------
#
#Food
FOOD = []
food = (x, y) ->
  "Create a food at the given position, every food as an amount of 10"
  amount: config.INITIAL_FOOD_LEVEL
  pos:
    x:x,y:y

generateFood = (nbFood)->
  _.times nbFood, ->
    x = Math.floor Math.random() * config.world_dim.x
    y = Math.floor Math.random() * config.world_dim.y
    food(x, y)

isThereFood = (pos) ->
  "find a food (with amount superior to 0) at the given position"
  _.find FOODS, (f) ->
    f.amount > 0 and
    utils.isSamePos f.pos, pos

FOODS = generateFood(config.NB_FOOD_VALUE)

module.exports =
  FOODS:FOODS,
  isThereFood: isThereFood
