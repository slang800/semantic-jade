assert = require "assert"
jade = require "../"

# shortcut
render = (str, options) ->
	fn = jade.compile(str, options)
	fn options


it "should support multi-line attrs", ->
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

it "should support standard attrs", ->
	assert.equal "<img src=\"&lt;script&gt;\"/>", render("img(src=\"<script>\")"), "Test attr escaping"
	assert.equal "<a data-attr=\"bar\"></a>", render("a(data-attr=\"bar\")")
	assert.equal "<a data-attr=\"bar\" data-attr-2=\"baz\"></a>", render("a(data-attr=\"bar\", data-attr-2=\"baz\")")
	assert.equal "<a title=\"foo,bar\"></a>", render("a(title= \"foo,bar\")")
	assert.equal "<a title=\"foo,bar\" href=\"#\"></a>", render("a(title= \"foo,bar\", href=\"#\")")
	assert.equal "<p class=\"foo\"></p>", render("p(class='foo')"), "Test single quoted attrs"
	assert.equal "<input type=\"checkbox\" checked=\"checked\"/>", render("input( type=\"checkbox\", checked )")
	assert.equal "<input type=\"checkbox\" checked=\"checked\"/>", render("input( type=\"checkbox\", checked = true )")
	assert.equal "<input type=\"checkbox\"/>", render("input(type=\"checkbox\", checked= false)")
	assert.equal "<input type=\"checkbox\"/>", render("input(type=\"checkbox\", checked= null)")
	assert.equal "<input type=\"checkbox\"/>", render("input(type=\"checkbox\", checked= undefined)")
	assert.equal "<img src=\"/foo.png\"/>", render("img(src=\"/foo.png\")"), "Test attr ="
	assert.equal "<img src=\"/foo.png\"/>", render("img(src  =  \"/foo.png\")"), "Test attr = whitespace"
	assert.equal "<img src=\"/foo.png\"/>", render("img(src=\"/foo.png\")"), "Test attr :"
	assert.equal "<img src=\"/foo.png\"/>", render("img(src  =  \"/foo.png\")"), "Test attr : whitespace"
	assert.equal "<img src=\"/foo.png\" alt=\"just some foo\"/>", render("img(src=\"/foo.png\", alt=\"just some foo\")")
	assert.equal "<img src=\"/foo.png\" alt=\"just some foo\"/>", render("img(src = \"/foo.png\", alt = \"just some foo\")")
	assert.equal "<p class=\"foo,bar,baz\"></p>", render("p(class=\"foo,bar,baz\")")
	assert.equal "<a href=\"http://google.com\" title=\"Some : weird = title\"></a>", render("a(href= \"http://google.com\", title= \"Some : weird = title\")")
	assert.equal "<label for=\"name\"></label>", render("label(for=\"name\")")
	assert.equal "<meta name=\"viewport\" content=\"width=device-width\"/>", render("meta(name= 'viewport', content='width=device-width')"), "Test attrs that contain attr separators"
	assert.equal "<div style=\"color= white\"></div>", render("div(style='color= white')")
	assert.equal "<div style=\"color: white\"></div>", render("div(style='color: white')")
	assert.equal "<p class=\"foo\"></p>", render("p('class'='foo')"), "Test keys with single quotes"
	assert.equal "<p class=\"foo\"></p>", render("p(\"class\"= 'foo')"), "Test keys with double quotes"
	assert.equal "<p data-lang=\"en\"></p>", render("p(data-lang = \"en\")")
	assert.equal "<p data-dynamic=\"true\"></p>", render("p(\"data-dynamic\"= \"true\")")
	assert.equal "<p data-dynamic=\"true\" class=\"name\"></p>", render("p(\"class\"= \"name\", \"data-dynamic\"= \"true\")")
	assert.equal "<p data-dynamic=\"true\"></p>", render("p('data-dynamic'= \"true\")")
	assert.equal "<p data-dynamic=\"true\" class=\"name\"></p>", render("p('class'= \"name\", 'data-dynamic'= \"true\")")
	assert.equal "<p data-dynamic=\"true\" yay=\"yay\" class=\"name\"></p>", render("p('class'= \"name\", 'data-dynamic'= \"true\", yay)")
	assert.equal "<input checked=\"checked\" type=\"checkbox\"/>", render("input(checked, type=\"checkbox\")")
	assert.equal "<a data-foo=\"{ foo: 'bar', bar= 'baz' }\"></a>", render("a(data-foo  = \"{ foo: 'bar', bar= 'baz' }\")")
	assert.equal "<meta http-equiv=\"X-UA-Compatible\" content=\"IE=edge,chrome=1\"/>", render("meta(http-equiv=\"X-UA-Compatible\", content=\"IE=edge,chrome=1\")")
	assert.equal "<div style=\"background: url(/images/test.png)\">Foo</div>", render("div(style= 'background: url(/images/test.png)') Foo")
	assert.equal "<div style=\"background = url(/images/test.png)\">Foo</div>", render("div(style= 'background = url(/images/test.png)') Foo")
	assert.equal "<div style=\"foo\">Foo</div>", render("div(style= ['foo', 'bar'][0]) Foo")
	assert.equal "<div style=\"bar\">Foo</div>", render("div(style= { foo: 'bar', baz: 'raz' }['foo']) Foo")
	assert.equal "<a href=\"def\">Foo</a>", render("a(href='abcdefg'.substr(3,3)) Foo")
	assert.equal "<a href=\"def\">Foo</a>", render("a(href={test: 'abcdefg'}.test.substr(3,3)) Foo")
	assert.equal "<a href=\"def\">Foo</a>", render("a(href={test: 'abcdefg'}.test.substr(3,[0,3][1])) Foo")
	assert.equal "<rss xmlns:atom=\"atom\"></rss>", render("rss(xmlns:atom=\"atom\")")
	assert.equal "<rss xmlns:atom=\"atom\"></rss>", render("rss('xmlns:atom'=\"atom\")")
	assert.equal "<rss xmlns:atom=\"atom\"></rss>", render("rss(\"xmlns:atom\"='atom')")
	assert.equal "<rss xmlns:atom=\"atom\" foo=\"bar\"></rss>", render("rss('xmlns:atom'=\"atom\", 'foo'= 'bar')")
	assert.equal "<a data-obj=\"{ foo: 'bar' }\"></a>", render("a(data-obj= \"{ foo: 'bar' }\")")
	assert.equal "<meta content=\"what's up? 'weee'\"/>", render("meta(content=\"what's up? 'weee'\")")