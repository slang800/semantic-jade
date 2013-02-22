Node = require './node'

class BlockComment extends Node
	###*
	 * Initialize a `BlockComment` with the given `block`.
	 * @param {String} val
	 * @param {Block} block
	 * @param {Boolean} buffer
	 * @private
	###
	constructor: (val, block, buffer) ->
		@block = block
		@val = val
		@buffer = buffer


module.exports = BlockComment