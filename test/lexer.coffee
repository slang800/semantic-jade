Lexer = require '../lib/lexer'

#shortcut
stringify = (variable) ->
	JSON.stringify(variable, null, '    ')


it 'should parse attrs', ->
	test_lexer = new Lexer('a(foo="bar", bar=\'baz\', checked)')
	tokens = []
	while (token = test_lexer.next()).type isnt 'eos'
		tokens.push(token)
	
	stringify(tokens).should.equal(
		stringify([
			{
				type: 'tag',
				line: 1,
				val: 'a',
				selfClosing: false
			},
			{
				type: 'attrs',
				line: 1,
				val: undefined,
				attrs:
					foo:'"bar"',
					bar:'\'baz\'',
					checked: true
				escaped:{
					foo:true
					bar:true
					checked:true
				}
			}
		])
	)
