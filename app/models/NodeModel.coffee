define ['backbone'], (Backbone) ->

  class NodeModel extends Backbone.Model
    defaults:
      name: ''
      tags: []
      description: ''
      url: ''
      size: ''
      color: ''

    schema:
      name: { type: 'Text', validators: ['required'] }
      url: { type: 'Text', validators: ['url'] }
      description: 'TextArea'
      tags: { type: 'List', itemType: 'Text' }

    validate: ->
      if !@get('name')
        'Your node must have a name.'
