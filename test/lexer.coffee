Lexer = require '../lib/lexer'

#shortcut
stringify = (variable) ->
	JSON.stringify(variable, null, '    ')

tokenize = (str) ->
	test_lexer = new Lexer(str)
	tokens = []
	while (token = test_lexer.next()).type isnt 'eos'
		tokens.push(token)

	return tokens
	

describe 'Lexer.attrs()', ->
	it 'should recognize text attrs', ->
		stringify(
			tokenize('''
			a(
				foo="bar"
				bar=\'baz\'
				interpolate=\'#{nope}\'
			)
			''')[1].val
		).should.equal(
			stringify(
				attrs:
					foo: '\"bar\"'
					bar: '\'baz\''
					interpolate: '\'#{nope}\''
				escape:
					foo: true
					bar: true
					interpolate: true
			)
		)

	it 'should recognize boolean attrs', ->
		stringify(
			tokenize('''
			a(
				checked
				blah=true
			)
			''')[1].val
		).should.equal(
			stringify(
				attrs:
					checked: ''
					blah: 'true'
				escape:
					checked: true
					blah: true
			)
		)

	it 'should recognize data attrs', ->
		stringify(
			tokenize('''
			a(
				data={semantic: 'jade'}
				more_data=['semantic', 'jade']
			)
			''')[1].val
		).should.equal(
			stringify(
				attrs:
					data: '{semantic: \'jade\'}'
					more_data: '[\'semantic\', \'jade\']'
				escape:
					data: true
					more_data: true
			)
		)