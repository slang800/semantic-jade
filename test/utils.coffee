utils = require '../lib/utils'

#shortcut
stringify = (variable) ->
	JSON.stringify(variable, null, '\t')

describe 'utils.match_delimiters()', ->
	it 'should handle matching brackets', ->
		stringify(utils.match_delimiters(
			'(class=[\'foo\', \'bar\', \'baz\'])\n\n'
		)).should.equal(
			stringify([
				'(class=[\'foo\', \'bar\', \'baz\'])'
				'class=[\'foo\', \'bar\', \'baz\']'
			])
		)
