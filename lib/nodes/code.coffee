#Module dependencies
Node = require("./node")

###
Initialize a `Code` node with the given code `val`.
Code may also be optionally buffered and escaped.

@param {String} val
@param {Boolean} buffer
@param {Boolean} escape
@api public
###
class Code extends Node
	constructor: (val, buffer, escape) ->
		@val = val
		@buffer = buffer
		@escape = escape
		@debug = false if val.match(/^ *else/)

module.exports = Code