#Module dependencies
Node = require("./node")

###
Initialize a `Doctype` with the given `val`.

@param {String} val
@api public
###
class Doctype extends Node
	constructor: (val) ->
		@val = val

module.exports = Doctype