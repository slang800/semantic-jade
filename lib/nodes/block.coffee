#Module dependencies
Node = require("./node")

###
Initialize a new `Block` with an optional `node`.

@param {Node} node
@api public
###
class Block extends Node
	constructor: (node) ->
		@nodes = []
		@push node if node

		#Block flag
		@isBlock = true


	###
	Replace the nodes in `other` with the nodes
	in `this` block.

	@param {Block} other
	@api private
	###
	replace: (other) ->
		other.nodes = @nodes


	###
	Pust the given `node`.

	@param {Node} node
	@return {Number}
	@api public
	###
	push: (node) ->
		@nodes.push node


	###
	Check if this block is empty.

	@return {Boolean}
	@api public
	###
	isEmpty: ->
		0 is @nodes.length


	###
	Unshift the given `node`.

	@param {Node} node
	@return {Number}
	@api public
	###
	unshift: (node) ->
		@nodes.unshift node


	###
	Return the "last" block, or the first `yield` node.

	@return {Block}
	@api private
	###
	includeBlock: ->
		ret = @

		for node in @nodes
			if node.yield_tok then return node
			else if node.textOnly then continue
			else if node.includeBlock then ret = node.includeBlock()
			else if node.block and not node.block.isEmpty() then ret = node.block.includeBlock()
			if ret.yield_tok then return ret

		ret


	###
	Return a clone of this block.

	@return {Block}
	@api private
	###
	clone: ->
		clone = new Block

		for node in @nodes
			clone.push node.clone()

		clone


module.exports = Block