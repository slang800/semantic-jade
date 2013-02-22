Node = require './node'

class Literal extends Node
	###*
	 * Initialize a `Literal` node with the given `str`.
	 * @param {String} str
	 * @private
	###
	constructor: (str) ->
		@str = str

module.exports = Literal