Node = require './node'

###
Initialize a `Comment` with the given `val`, optionally `buffer`,
otherwise the comment may render in the output.

@param {String} val
@param {Boolean} buffer
@private
###
class Comment extends Node
	constructor: (val, buffer) ->
		@val = val
		@buffer = buffer


module.exports = Comment