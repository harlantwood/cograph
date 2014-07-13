define ['jquery', 'underscore', 'backbone', 'backbone-forms', 'list', 'backbone-forms-bootstrap'
 'text!templates/details_box.html', 'text!templates/edit_form.html', 'cs!models/NodeModel', 'cs!models/ConnectionModel',
 'bootstrap-color'],
  ($, _, Backbone, bbf, list, bbfb, detailsTemplate, editFormTemplate, NodeModel, ConnectionModel, ColorPicker) ->
    class DetailsView extends Backbone.View
      el: $ '#sidebar'

      events:
        'click .close' : 'closeDetail'
        'click #edit-node-button': 'editNode'
        'click #edit-connection-button': 'editConnection'
        'submit form': 'saveNodeConnection'
        'click #archive-node-button': 'archiveNode'
        'click #archive-connection-button': 'archiveConnection'
        'click #delete-button': 'deleteObj'
        'click #expand-node-button': 'expandNode'

      initialize: ->
        @model.nodes.on 'change:selected', @update, this
        @model.connections.on 'change:selected', @update, this
        @model.on 'create:connection', @editConnection, this

      update: (nodeConnection) ->
        selectedNC = @getSelectedNode() || @getSelectedConnection()

        $("#details-container").empty()
        if selectedNC
          workspaceSpokes = @model.getSpokes selectedNC
          $("#details-container").append _.template(detailsTemplate, {node:selectedNC, spokes:workspaceSpokes})
          @updateColor @model.defaultColors[selectedNC.get('color')]
          selectedNC.on "change:color", (nc) => @updateColor @model.defaultColors[selectedNC.get('color')]

      updateColor: (color) ->
        $('.panel-body', '#details-container').css 'background', color

      closeDetail: () ->
        $('#details-container').empty()
        if @getSelectedNode()
          @getSelectedNode().set 'selected', false
        if @getSelectedConnection()
          @getSelectedConnection().set 'selected', false

      editNode: () ->
        @editNodeConnection @getSelectedNode()

      editConnection: () ->
        @editNodeConnection @getSelectedConnection()

      editNodeConnection: (nodeConnection) ->
        @nodeConnectionForm = new Backbone.Form(
          model: nodeConnection
          template: _.template(editFormTemplate)
        ).on('name:blur url:blur tags:blur', (form, editor) ->
          form.fields[editor.key].validate()
        ).render()

        $('#details-container .panel-body').empty().append(@nodeConnectionForm.el)
        $('input[name=name]', @el).focus()

        isNode = nodeConnection.constructor.name is 'NodeModel'
        colorOptions = colors:[(val for color, val of @model.defaultColors when !((color is 'grey') and isNode))]
        $('.colorpalette').colorPalette(colorOptions).on 'selectColor', (e) =>
          colorValue = e.color
          nodeConnection.set 'color', _.invert(@model.defaultColors)[colorValue]
          nodeConnection.save()

      saveNodeConnection: (e) ->
        e.preventDefault()
        @nodeConnectionForm.commit()
        @nodeConnectionForm.model.save()
        @update()
        false

      archiveNode: () ->
        @model.removeNode @getSelectedNode()
        @closeDetail()

      archiveConnection: () ->
        @model.removeConnection @getSelectedConnection()
        @closeDetail()

      deleteObj: ->
        if @getSelectedNode()
          @model.deleteNode @getSelectedNode()
        else if @getSelectedConnection()
          @model.deleteConnection @getSelectedConnection()
        @closeDetail()

      expandNode: ->
        @getSelectedNode().getNeighbors (neighbors) =>
          for node in neighbors
            newNode = new NodeModel node
            if @model.putNode newNode #this checks to see if the node has passed the filter
              newNode.getConnections @model.nodes, (connections) =>
                @model.putConnection new ConnectionModel conn for conn in connections

      getSelectedNode: ->
        selectedNode = @model.nodes.findWhere {'selected': true}

      getSelectedConnection: ->
        selectedConnection = @model.connections.findWhere {'selected': true}
