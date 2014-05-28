define ['jquery', 'backbone', 'bloodhound', 'typeahead', 'cs!models/GraphModel'],
  ($, Backbone, Bloodhound, typeahead, GraphModel) ->
    class SearchView extends Backbone.View
      el: $ '#search-form'

      events:
        'click button': 'search'

      initialize: ->
        substringMatcher = (gm) =>
          findMatches = (q, cb) =>
            matches = @findMatchingNames q, gm.nodes.pluck('name')
            matches = _.map matches, (name) -> value: name
            cb matches

        $('#search-input').typeahead(
          hint: true,
          highlight: true,
          minLength: 1,
          autoselect: true
        ,
          name: 'node-names',
          source: substringMatcher(@model)
        )

        $('#search-input').on 'typeahead:selected',
          (e, sugg, dataset) => @search()

      search: ->
        searchTerm = $('#search-input').val()
        node = @findNode searchTerm
        if node
          @model.select node
          $('#search-input').val('')

      findNode: (name) ->
        matchedNames = @findMatchingNames(name, @model.nodes.pluck('name'))
        @model.nodes.findWhere name: matchedNames[0]

      findMatchingNames: (query, allNames) ->
        regex = new RegExp(query,'i')
        _.filter(allNames, (name) -> regex.test(name))
