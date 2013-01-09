#Module dependencies
Node = require("./node")

###
Initialize a `Literal` node with the given `str`.

@param {String} str
@api public
###
class Literal extends Node
	constructor: (str) ->
		@str = str

module.exports = Literal