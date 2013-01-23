Node = require './node'

###
Initialize a `Code` node with the given code `val`.
Code may also be optionally buffered and escaped.

@param {String} val
@param {Boolean} buffer
@param {Boolean} escape
@private
###
class Code extends Node
	constructor: (val, buffer, escape) ->
		@val = val
		@buffer = buffer
		@escape = escape

module.exports = Code