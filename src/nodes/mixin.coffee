#Module dependencies
Attrs = require("./attrs")

###
Initialize a new `Mixin` with `name` and `block`.

@param {String} name
@param {String} args
@param {Block} block
@api public
###
class Mixin extends Attrs
	constructor: (name, args, block, call) ->
		@name = name
		@args = args
		@block = block
		@attrs = []
		@call = call

module.exports = Mixin