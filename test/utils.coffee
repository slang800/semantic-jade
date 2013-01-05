utils = require '../lib/utils'
runtime = require '../lib/runtime' # probably should be in its own file

#shortcut
stringify = (variable) ->
	JSON.stringify(variable, null, '\t')

describe 'utils.match_delimiters()', ->
	it 'should handle matching brackets', ->
		stringify(utils.match_delimiters(
			'(class=[\'foo\', \'bar\', \'baz\'])\n\n',
			'(',
			')',
		)).should.equal(
			stringify([
				'(class=[\'foo\', \'bar\', \'baz\'])'
				'class=[\'foo\', \'bar\', \'baz\']'
			])
		)

merge = runtime.merge

describe 'utils.merge()', ->
	it 'should merge classes into strings', ->
		merge(
			{foo: 'bar'},
			{bar: 'baz'},
		).should.eql(
			foo: 'bar'
			bar: 'baz'
		)

		merge(
			{class: []},
			{},
		).should.eql(
			class: ''
		)

		merge(
			{class: []},
			{class: []},
		).should.eql(
			class: ''
		)

		merge(
			{class: []},
			{class: ['foo']},
		).should.eql(
			class: 'foo'
		)

		merge(
			{class: ['foo']},
			{},
		).should.eql(
			class: 'foo'
		)

		merge(
			{class: ['foo']},
			{class: ['bar']},
		).should.eql(
			class: 'foo bar'
		)

		merge(
			{class: ['foo', 'raz']},
			{class: ['bar', 'baz']},
		).should.eql(
			class: 'foo raz bar baz'
		)

		merge(
			{class: 'foo'},
			{class: 'bar'},
		).should.eql(
			class: 'foo bar'
		)

		merge(
			{class: 'foo'},
			{class: 'bar'},
		).should.eql(
			class: 'foo bar'
		)

		merge(
			{class: 'foo'},
			{class: ['bar', 'baz']},
		).should.eql(
			class: 'foo bar baz'
		)

		merge(
			{class: ['foo', 'bar']},
			{class: 'baz'},
		).should.eql(
			class: 'foo bar baz'
		)

		merge(
			{class: ['foo', null, 'bar']},
			{class: [undefined, null, 0, 'baz']},
		).should.eql(
			class: 'foo bar 0 baz'
		)
###
describe 'utils.interpolate', ->
	it 'should handle multiple instances of interpolation', ->
		stringify(
			utils.interpolate '#{k}: #{v}'
		).should.equal(
			'#{k}: #{v}'
		)###