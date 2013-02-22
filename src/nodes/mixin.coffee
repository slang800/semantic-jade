Attrs = require './attrs'

class Mixin extends Attrs
	###*
	 * Initialize a new `Mixin` with `name` and `block`.
	 * @param {String} name
	 * @param {String} args
	 * @param {Block} block
	 * @private
	###
	constructor: (name, args, block, call) ->
		@name = name
		@args = args
		@block = block
		@attrs = []
		@call = call

module.exports = Mixin