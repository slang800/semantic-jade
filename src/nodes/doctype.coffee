Node = require './node'

class Doctype extends Node
	###*
	 * Initialize a `Doctype` with the given `val`.
	 * @param {String} val
	 * @private
	###
	constructor: (val) ->
		@val = val

module.exports = Doctype