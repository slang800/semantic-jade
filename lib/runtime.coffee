###
Lame Array.isArray() polyfill for now.
###
unless Array.isArray
	Array.isArray = (arr) ->
		"[object Array]" is Object::toString.call(arr)

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
	ac = a["class"]
	bc = b["class"]
	if ac or bc
		ac = ac or []
		bc = bc or []
		ac = [ac] unless Array.isArray ac
		bc = [bc] unless Array.isArray bc
		ac = ac.filter nulls
		bc = bc.filter nulls
		a["class"] = ac.concat(bc).join " "
	for key of b
		a[key] = b[key] unless key is "class"
	a

###
Filter null `val`s. ==

@param {Mixed} val
@return {Mixed}
@private
###
nulls = (val) ->
	val?


###
Render the given attributes object.

@param {Object} obj
@param {Object} escaped
@return {String}
@private
###
exports.attrs = (obj, escaped) ->
	buf = []
	terse = obj.terse
	delete obj.terse

	keys = Object.keys obj
	len = keys.length
	if len
		buf.push ""
		i = 0

		while i < len
			`var key = keys[i]
				, val = obj[key];

			if ('boolean' == typeof val || null == val) {
				if (val) {
					terse
						? buf.push(key)
						: buf.push(key + '="' + key + '"');
				}
			} else if (0 == key.indexOf('data') && 'string' !== typeof val) {
				buf.push(key + "='" + JSON.stringify(val) + "'");
			} else if ('class' == key && Array.isArray(val)) {
				buf.push(key + '="' + exports.escape(val.join(' ')) + '"');
			} else if (escaped && escaped[key]) {
				buf.push(key + '="' + exports.escape(val) + '"');
			} else {
				buf.push(key + '="' + val + '"');
			}`
			++i

	buf.join " "


###
Escape the given string of `html`.

@param {String} html
@return {String}
@private
###
exports.escape = (html) ->
	String(html).replace(/&(?!(\w+|\#\d+);)/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace /"/g, "&quot;"


###
Re-throw the given `err` in context to the
the jade in `filename` at the given `lineno`.

@param {Error} err
@param {String} filename
@param {String} lineno
@private
###
exports.rethrow = (err, filename, lineno) ->
	throw err  unless filename
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
	err.message = (filename or "Jade") + ":" + lineno + "\n" + context + "\n\n" + err.message
	throw err
