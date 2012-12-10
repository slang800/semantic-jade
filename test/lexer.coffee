Lexer = require '../lib/lexer'

#shortcut
stringify = (variable) ->
	JSON.stringify(variable, null, '    ')


it 'should tokenize attrs', ->
	test_lexer = new Lexer('''
		a(
			foo="bar",
			bar=\'baz\'
			checked,
			blah=true
			interpolate=\'#{nope}\'
			data={semantic: \'jade\'},
			more_data=[semantic: \'jade\']

		)
	''')
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
					foo:'"bar"'
					bar:'\'baz\''
					checked: true
					blah: true
					interpolate: '\'#{nope}\''
					data: {
						semantic: 'jade'
					}
					more_data: [
						'semantic',
						'jade'
					]
				escaped:{
					foo:true
					bar:true
					checked:true
					blah:true
					interpolate:true
					data:true
					more_data:true
				}
			}
		])
	)