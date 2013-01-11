utils = require('./utils')

exports.escape = utils.escape

###
Lame Array.isArray() polyfill for now.
###
unless Array.isArray
	Array.isArray = (arr) ->
		'[object Array]' is Object::toString.call(arr)

###
Lame Object.keys() polyfill for now.
###
unless Object.keys
	Object.keys = (obj) ->
		arr = []
		for key of obj
			arr.push key if obj.hasOwnProperty(key)
		arr

###
Merge two attribute objects giving precedence
to values in object `b`. Classes are special-cased
allowing for arrays and merging/joining appropriately
resulting in a string.

@param {Object} a
@param {Object} b
@return {Object} a
@private
###
exports.merge = (a, b) ->
	ac = a['class']
	bc = b['class']
	if ac or bc
		ac = ac or []
		bc = bc or []
		ac = [ac] unless Array.isArray ac
		bc = [bc] unless Array.isArray bc
		ac = ac.filter nulls
		bc = bc.filter nulls
		a['class'] = ac.concat(bc).join ' '
	for key of b
		a[key] = b[key] unless key is 'class'
	a

###
Filter null `val`s. ==

@param {Mixed} val
@return {Mixed}
@private
###
nulls = (val) ->
	val?


###*
 * Render the given attributes object.
 * @param {Object} obj
 * @return {String}
 * @private
###
exports.attrs = (obj) ->
	buf = ['']

	attrs = {}
	for attr in obj.attrs
		val = attr.val
		key = attr.name
		if typeof val is 'boolean' or val is null or not val?
			if val
				if obj.terse
					buf.push(key)
				else
					buf.push("#{key}=\"#{key}\"")
		else
			if 'class' is key
				if Array.isArray(val)
					val = val.join ' '

				if attrs['class']?
					attrs['class'] = attrs['class'] + ' ' + val
				else
					attrs['class'] = val
			else
				if 'string' isnt typeof val
					val = JSON.stringify(val)
				attrs[key] = val

	for key, value of attrs
		if val isnt ''
			buf.push("#{key}=\"#{utils.escape(value)}\"")

	return buf.join " "

###
Re-throw the given `err` in context to the
the jade in `filename` at the given `lineno`.

@param {Error} err
@param {String} filename
@param {String} lineno
@private
###
exports.rethrow = (err, filename, lineno) ->
	throw err unless filename
	context = 3
	str = require("fs").readFileSync(filename, "utf8")
	lines = str.split("\n")
	start = Math.max(lineno - context, 0)
	end = Math.min(lines.length, lineno + context)
	
	# Error context
	context = lines.slice(start, end).map((line, i) ->
		curr = i + start + 1
		((if curr is lineno then "  > " else "    ")) + curr + "| " + line
	).join("\n")
	
	# Alter exception message
	err.path = filename
	err.message = "#{(filename or "Jade")}:#{lineno}\n#{context}\n\n#{err.message}"
	throw err
