module.exports =

	# Wrap text with CDATA block.
	cdata: (str) ->
		"<![CDATA[\\n" + str + "\\n]]>"


	# Transform sass to css.
	sass: (str) ->
		str = str.replace(/\\n/g, "\n")
		sass = require("sass").render(str).replace(/\n/g, "\\n")
		"\\n" + sass


	# Transform stylus to css.
	stylus: (str, options) ->
		ret = undefined
		str = str.replace(/\\n/g, "\n")
		stylus = require("stylus")
		style = stylus(str, options)
		style.define "url", stylus.url({}) if options.inline is "true"
		style.render (err, css) ->
			throw err if err
			ret = css.replace(/\n/g, "\\n")

		"\\n" + ret


	# Transform less to css.
	less: (str) ->
		ret = undefined
		str = str.replace(/\\n/g, "\n")
		require("less").render str, (err, css) ->
			throw err if err
			ret = css.replace(/\n/g, "\\n")

		"\\n" + ret


	# Transform markdown to html.
	markdown: (str) ->
		md = undefined
		
		# support markdown / discount
		try
			md = require("markdown")
		catch err
			try
				md = require("discount")
			catch err
				try
					md = require("markdown-js")
				catch err
					try
						md = require("marked")
					catch err
						throw new Error("Cannot find markdown library, install markdown, discount, or marked.")
		str = str.replace(/\\n/g, "\n")
		md.parse(str).replace(/\n/g, "\\n").replace /'/g, "&#39;"

	# Transform github flavored markdown to html.
	ghm: (str, options) ->
		# support markdown / discount
		ghm = require("ghm")
		"\\n" + ghm.parse(str.replace(/\\n/g, "\n"), options.project).replace(/\n/g, "\\n")


	# Transform coffeescript to javascript.
	coffeescript: (str) ->
		"\\n" + require("coffee-script").compile(str).replace(/\\/g, "\\\\").replace(/\n/g, "\\n")