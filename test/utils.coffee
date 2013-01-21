utils = require '../lib/utils'

#shortcut
stringify = (variable) ->
	JSON.stringify(variable, null, '\t')

describe 'utils.balance_string()', ->
	it 'should handle matching brackets', ->
		utils.balance_string(
			'{\'fo}o\':\'ba{r\', \'ba}z\': 42}blah{meh}',
		).should.equal(
			'{\'fo}o\':\'ba{r\', \'ba}z\': 42}'
		)

	it 'should deal with interpolation', ->
		utils.balance_string(
			'{"blah } meh"} blah blah',
		).should.equal(
			'{"blah } meh"}'
		)

	it 'should be able to match parenthesis', ->
		utils.balance_string(
			'(class=[\'foo\', \'bar\', \'baz\'])'
		).should.equal(
			'(class=[\'foo\', \'bar\', \'baz\'])'
		)

		utils.balance_string(
			'("#{")}" + \')}\' + (")")} )") blah ('
		).should.equal(
			'("#{")}" + \')}\' + (")")} )")'
		)

describe 'utils.process_str', ->
	it 'should escape dbl quotes in strings', ->
		utils.process_str(
			'"p"'
		).should.equal(
			'\\"p\\"'
		)

	it 'should handle multiple instances of interpolation', ->
		utils.process_str(
			'#{k}: #{v}'
		).should.equal(
			'#{k}: #{v}'
		)

	it 'should handle `!{}` interpolation', ->
		utils.process_str(
			'#{k}: !{v}'
		).should.equal(
			'#{k}: #{escape(v)}'
		)

	it 'should handle strings with only interpolation', ->
		utils.process_str(
			'!{"v"}'
		).should.equal(
			'#{escape("v")}'
		)