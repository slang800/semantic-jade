assert = require 'assert'
jade = require "../"

# shortcut
render = (str, options) ->
	fn = jade.compile(str, options)
	fn options


describe 'attributes', ->
	it "should support multi-line attrs w/ funky formatting", ->
		output = '<a foo="bar" bar="baz" checked="checked">foo</a>'

		render('''
			a(foo="bar"
			  bar="baz"
			  checked) foo
			'''
		).should.equal(output)

		render('''
			a(foo="bar"
			bar="baz"
			checked
			) foo
			'''
		).should.equal(output)

		render('''
			a(foo="bar"
			,bar="baz"
			,checked) foo
			'''
		).should.equal(output)

		render('''
			a(foo="bar",
			bar="baz",
			checked) foo
			'''
		).should.equal(output)


	it "should support single quoted attrs", ->
		render(
			'p(class=\'foo\')'
		).should.equal(
			'<p class="foo"></p>'
		)


	it "should escape attrs", ->
		render(
			'img(src="<script>")'
		).should.equal(
			'<img src="&lt;script&gt;"/>'
		)


	it "should support shorthands for checkboxes", ->
		render(
			'input( type="checkbox", checked )'
		).should.equal(
			'<input type="checkbox" checked="checked"/>'
		)

		render(
			'input( type="checkbox", checked = true )'
		).should.equal(
			'<input type="checkbox" checked="checked"/>'
		)

		render(
			'input(type="checkbox", checked= false)'
		).should.equal(
			'<input type="checkbox"/>'
		)

		render(
			'input(type="checkbox", checked= null)'
		).should.equal(
			'<input type="checkbox"/>'
		)

		render(
			'input(type="checkbox", checked= undefined)'
		).should.equal(
			'<input type="checkbox"/>'
		)


	it "should support standard attrs", ->
		render(
			'a(data-attr="bar")'
		).should.equal(
			'<a data-attr="bar"></a>'
		)

		render(
			'a(data-attr="bar", data-attr-2="baz")'
		).should.equal(
			'<a data-attr="bar" data-attr-2="baz"></a>'
		)

		render(
			'a(title= "foo,bar")'
		).should.equal(
			'<a title="foo,bar"></a>'
		)

		render(
			'a(title= "foo,bar", href="#")'
		).should.equal(
			'<a title="foo,bar" href="#"></a>'
		)


		# "Test attr ="
		render(
			'img(src="/foo.png")'
		).should.equal(
			'<img src="/foo.png"/>'
		)

		#'Test attr = whitespace'
		render(
			'img(src  =  "/foo.png")'
		).should.equal(
			'<img src="/foo.png"/>'
		)
		
		render(
			'img(src="/foo.png", alt="just some foo")'
		).should.equal(
			'<img src="/foo.png" alt="just some foo"/>'
		)
		
		render(
			'img(src = "/foo.png", alt = "just some foo")'
		).should.equal(
			'<img src="/foo.png" alt="just some foo"/>'
		)
		
		render(
			'p(class="foo,bar,baz")'
		).should.equal(
			'<p class="foo,bar,baz"></p>'
		)
		
		render(
			'a(href= "http://google.com", title= "Some : weird = title")'
		).should.equal(
			'<a href="http://google.com" title="Some : weird = title"></a>'
		)
		
		render(
			'label(for="name")'
		).should.equal(
			'<label for="name"></label>'
		)
		
		#'Test attrs that contain attr separators'
		render(
			'meta(name= \'viewport\', content=\'width=device-width\')'
		).should.equal(
			'<meta name="viewport" content="width=device-width"/>'
		)
		
		render(
			'div(style=\'color= white\')'
		).should.equal(
			'<div style="color= white"></div>'
		)
		
		render(
			'div(style=\'color: white\')'
		).should.equal(
			'<div style="color: white"></div>'
		)
		
		#'Test keys with single quotes'
		render(
			'p(\'class\'=\'foo\')'
		).should.equal(
			'<p class="foo"></p>'
		)
		
		#'Test keys with double quotes'
		render(
			'p("class"= \'foo\')'
		).should.equal(
			'<p class="foo"></p>'
		)
		
		render(
			'p(data-lang = "en")'
		).should.equal(
			'<p data-lang="en"></p>'
		)
		
		render(
			'p("data-dynamic"= "true")'
		).should.equal(
			'<p data-dynamic="true"></p>'
		)
		
		render(
			'p("class"= "name", "data-dynamic"= "true")'
		).should.equal(
			'<p data-dynamic="true" class="name"></p>'
		)
		
		render(
			'p(\'data-dynamic\'= "true")'
		).should.equal(
			'<p data-dynamic="true"></p>'
		)
		
		render(
			'p(\'class\'= "name", \'data-dynamic\'= "true")'
		).should.equal(
			'<p data-dynamic="true" class="name"></p>'
		)
		
		render(
			'p(\'class\'= "name", \'data-dynamic\'= "true", yay)'
		).should.equal(
			'<p data-dynamic="true" yay="yay" class="name"></p>'
		)
		
		render(
			'input(checked, type="checkbox")'
		).should.equal(
			'<input checked="checked" type="checkbox"/>'
		)
		
		render(
			'a(data-foo  = "{ foo: \'bar\', bar= \'baz\' }")'
		).should.equal(
			'<a data-foo="{ foo: \'bar\', bar= \'baz\' }"></a>'
		)
		
		render(
			'meta(http-equiv="X-UA-Compatible", content="IE=edge,chrome=1")'
		).should.equal(
			'<meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1"/>'
		)
		
		render(
			'div(style= \'background: url(/images/test.png)\') Foo'
		).should.equal(
			'<div style="background: url(/images/test.png)">Foo</div>'
		)
		
		render(
			'div(style= \'background = url(/images/test.png)\') Foo'
		).should.equal(
			'<div style="background = url(/images/test.png)">Foo</div>'
		)
		
		render(
			'div(style= [\'foo\', \'bar\'][0]) Foo'
		).should.equal(
			'<div style="foo">Foo</div>'
		)
		
		render(
			'div(style= { foo: \'bar\', baz: \'raz\' }[\'foo\']) Foo'
		).should.equal(
			'<div style="bar">Foo</div>'
		)
		
		render(
			'a(href=\'abcdefg\'.substr(3,3)) Foo'
		).should.equal(
			'<a href="def">Foo</a>'
		)
		
		render(
			'a(href={test: \'abcdefg\'}.test.substr(3,3)) Foo'
		).should.equal(
			'<a href="def">Foo</a>'
		)
		
		render(
			'a(href={test: \'abcdefg\'}.test.substr(3,[0,3][1])) Foo'
		).should.equal(
			'<a href="def">Foo</a>'
		)

	it "should ignore special chars in attrs", ->
		render(
			'rss(xmlns:atom="atom")'
		).should.equal(
			'<rss xmlns:atom="atom"></rss>'
		)
		
		render(
			'rss(\'xmlns:atom\'="atom")'
		).should.equal(
			'<rss xmlns:atom="atom"></rss>'
		)
		
		render(
			'rss("xmlns:atom"=\'atom\')'
		).should.equal(
			'<rss xmlns:atom="atom"></rss>'
		)
		
		render(
			'rss(\'xmlns:atom\'="atom", \'foo\'= \'bar\')'
		).should.equal(
			'<rss xmlns:atom="atom" foo="bar"></rss>'
		)
		
		render(
			'a(data-obj= "{ foo: \'bar\' }")'
		).should.equal(
			'<a data-obj="{ foo: \'bar\' }"></a>'
		)
		
		render(
			'meta(content="what\'s up? \'weee\'")'
		).should.equal(
			'<meta content="what\'s up? \'weee\'"/>'
		)