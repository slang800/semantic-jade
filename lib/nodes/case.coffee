#Module dependencies
Node = require("./node")

###
Initialize a new `Case` with `expr`.

@param {String} expr
@api public
###
class Case extends Node
	constructor: (expr, block) ->
		@expr = expr
		@block = block


module.exports = exports = Case

class When extends Node
	constructor: (expr, block) ->
		@expr = expr
		@block = block
		@debug = false

exports.When = When