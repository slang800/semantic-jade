Node = require './node'

class Text extends Node
	###*
	 * Initialize a `Text` node with optional `line`.
	 * @param {String} line
	 * @private
	###
	constructor: (line) ->
		@val = ''
		if typeof line is 'string'
			@val = line

		#Flag as text
		@isText = true

module.exports = Text