Node = require './node'

###
Initialize a `BlockComment` with the given `block`.

@param {String} val
@param {Block} block
@param {Boolean} buffer
@private
###
class BlockComment extends Node
	constructor: (val, block, buffer) ->
		@block = block
		@val = val
		@buffer = buffer


module.exports = BlockComment