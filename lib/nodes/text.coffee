#Module dependencies
Node = require("./node")

###
Initialize a `Text` node with optional `line`.

@param {String} line
@api public
###
class Text extends Node
	constructor: (line) ->
		@val = ""
		@val = line  if "string" is typeof line

		#Flag as text
		@isText = true

module.exports = Text