Node = require './node'

###*
 * Initialize a `Text` node with optional `line`.
 * @param {String} line
 * @private
###
class Text extends Node
	constructor: (line) ->
		@val = ''
		if typeof line is 'string'
			@val = line

		#Flag as text
		@isText = true

module.exports = Text