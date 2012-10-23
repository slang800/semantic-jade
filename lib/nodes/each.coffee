#Module dependencies
Node = require("./node")

###
Initialize an `Each` node, representing iteration

@param {String} obj
@param {String} val
@param {String} key
@param {Block} block
@api public
###
class Each extends Node
	constructor: (obj, val, key, block) ->
		@obj = obj
		@val = val
		@key = key
		@block = block

module.exports = Each