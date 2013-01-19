Attrs = require './attrs'
Block = require './block'
inlineTags = require '../inline-tags'

###
Initialize a `Tag` node with the given tag `name` and optional `block`.

@param {String} name
@param {Block} block
@api public
###
class Tag extends Attrs
	constructor: (name, block) ->
		@name = name
		@attrs = []
		@block = block or new Block


	###
	Clone this tag.

	@return {Tag}
	@api private
	###
	clone: ->
		clone = new Tag(@name, @block.clone())
		clone.line = @line
		clone.attrs = @attrs
		clone.textOnly = @textOnly
		clone


	###
	Check if this tag is an inline tag.

	@return {Boolean}
	@api private
	###
	isInline: ->
		~inlineTags.indexOf(@name)


	###
	Check if this tag's contents can be inlined. Used for pretty printing.

	@return {Boolean}
	@api private
	###
	canInline: ->
		isInline = (node) ->
			# Recurse if the node is a block
			return node.nodes.every(isInline) if node.isBlock
			node.isText or (node.isInline and node.isInline())

		nodes = @block.nodes
		
		# Empty tag
		return true unless nodes.length
		
		# Text-only or inline-only tag
		return isInline(nodes[0]) if nodes.length is 1
		
		# Multi-line inline-only tag
		if @block.nodes.every(isInline)
			for i in [1...nodes.length]
				return false if nodes[i - 1].isText and nodes[i].isText
			return true
		
		# Mixed tag
		false

module.exports = Tag