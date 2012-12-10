# Module dependencies.
jade = require "../"
fs = require "fs"

# test cases
cases = fs.readdirSync("test/cases").filter(
	(file) ->
		~file.indexOf(".jade")
).map(
	(file) ->
		file.replace ".jade", ""
)
cases.forEach (test) ->
	it test, ->
		path = "test/cases/" + test + ".jade"
		str = fs.readFileSync(path, "utf8")
		html = fs
			.readFileSync("test/cases/" + test + ".html", "utf8")
			.trim()
			.replace(/\r/g, "")

		fn = jade.compile(
			str,
			filename: path
			pretty: true
		)
		actual = fn(title: "Jade")
		actual.trim().should.equal html


