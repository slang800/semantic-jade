utils = require '../lib/utils'

#shortcut
stringify = (variable) ->
	JSON.stringify(variable, null, '\t')

describe 'balance_string', ->
	balance_string = utils.balance_string

	it 'should handle matching brackets', ->
		balance_string(
			'{\'fo}o\':\'ba{r\', \'ba}z\': 42}blah{meh}',
		).should.equal(
			'{\'fo}o\':\'ba{r\', \'ba}z\': 42}'
		)

	it 'should deal with interpolation', ->
		balance_string(
			'{"blah } meh"} blah blah',
		).should.equal(
			'{"blah } meh"}'
		)

	it 'should be able to match parenthesis', ->
		balance_string(
			'(class=[\'foo\', \'bar\', \'baz\'])'
		).should.equal(
			'(class=[\'foo\', \'bar\', \'baz\'])'
		)

		balance_string(
			'("#{")}" + \')}\' + (")")} )") blah ('
		).should.equal(
			'("#{")}" + \')}\' + (")")} )")'
		)


describe 'search', ->
	search = utils.search

	it 'should find a delimiter in a string', ->
		str = 'foo, foo:oof ,off'
		search(
			str,
			[',']
		).should.equal(
			'foo,'
		)

		search(
			str,
			[':']
		).should.equal(
			'foo, foo:'
		)

		search(
			str,
			['f']
		).should.equal(
			'f'
		)

	it 'should ignore delimiters in balanced groups', ->
		search(
			'style= [\'foo\', \'bar\'][1], foo) Foo',
			['=', ',', ')']
		).should.equal(
			'style='
		)

		search(
			' [\'foo\', \'bar\'][1], foo) Foo',
			['=', ',', ')']
		).should.equal(
			' [\'foo\', \'bar\'][1],'
		)

		search(
			' foo) Foo',
			['=', ',', ')']
		).should.equal(
			' foo)'
		)

	it 'should ignore delimiters in balanced groups (strings)', ->
		search(
			'src=\'/jquery.js\', foo',
			[',']
		).should.equal(
			'src=\'/jquery.js\','
		)



describe 'process_str', ->
	process_str = utils.process_str

	it 'should escape dbl quotes in strings', ->
		process_str(
			'"p"'
		).should.equal(
			'\\"p\\"'
		)

	it 'should handle multiple instances of interpolation', ->
		process_str(
			'#{k}: #{v}'
		).should.equal(
			'#{k}: #{v}'
		)

	it 'should handle `!{}` interpolation', ->
		process_str(
			'#{k}: !{v}'
		).should.equal(
			'#{k}: #{escape(v)}'
		)

	it 'should handle strings with only interpolation', ->
		process_str(
			'!{"v"}'
		).should.equal(
			'#{escape("v")}'
		)