#Module dependencies
Node = require("./node")
Block = require("./block")

###
Initialize a `Filter` node with the given
filter `name` and `block`.

@param {String} name
@param {Block|Node} block
@api public
###
class Filter extends Node
	constructor: (name, block, attrs) ->
		@name = name
		@block = block
		@attrs = attrs

module.exports = Filter