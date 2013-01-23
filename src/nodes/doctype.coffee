Node = require './node'

###
Initialize a `Doctype` with the given `val`.

@param {String} val
@private
###
class Doctype extends Node
	constructor: (val) ->
		@val = val

module.exports = Doctype