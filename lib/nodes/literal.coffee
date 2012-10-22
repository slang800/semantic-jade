#Module dependencies
Node = require("./node")

###
Initialize a `Literal` node with the given `str`.

@param {String} str
@api public
###

class Literal extends Node
	constructor: (str) ->
		@str = str.replace(/\\/g, "\\\\").replace(/\n|\r\n/g, "\\n").replace(/'/g, "\\'")

module.exports = Literal