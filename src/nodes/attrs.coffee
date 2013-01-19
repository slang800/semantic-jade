Node = require './node'
Block = require './block'

###
Initialize a `Attrs` node.

@api public
###
class Attrs extends Node
	constructor: ->
		@attrs = []


	###
	Set attribute `name` to `val`, keep in mind these become
	part of a raw js object literal, so to quote a value you must
	'"quote me"', otherwise or example 'user.name' is literal JavaScript.

	@param {String} name
	@param {String} val
	@param {Boolean} escaped
	@return {Tag} for chaining
	@api public
	###
	setAttribute: (name, val, escape) ->
		@attrs.push
			name: name
			val: val
			escape: escape

		this


	###
	Remove attribute `name` when present.

	@param {String} name
	@api public
	###
	removeAttribute: (name) ->
		for i in [0..@attrs.length]
			delete @attrs[i] if @attrs[i] and @attrs[i].name is name


	###
	Get attribute value by `name`.

	@param {String} name
	@return {String}
	@api public
	###
	getAttribute: (name) ->
		for i in [0..@attrs.length]
			return @attrs[i].val if @attrs[i] and @attrs[i].name is name

module.exports = Attrs