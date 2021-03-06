define ['jquery', 'backbone', 'cs!models/NodeModel','cs!models/ConnectionModel',
  'cs!models/FilterModel', 'cs!models/DocumentModel', 'socket-io'],
  ($, Backbone, NodeModel, ConnectionModel, FilterModel, DocumentModel, io) ->
    class ObjectCollection extends Backbone.Collection
      _docId: 0
      socket: io.connect("")

      initialize: ->
        @initBroadcastCreate()

        @socket.on @url()+":update", (objData) =>
          objData._id = parseInt(objData._id)
          id = objData._id
          existingObj = @findWhere {_id:id}
          if existingObj? then existingObj.set objData

        @initBroadcastDelete()

      initBroadcastCreate: ->
        @socket.on @url()+":create", (objData) =>
          @add new @model objData, {parse:true}

      initBroadcastDelete: ->
        @socket.on @url()+":delete", (objData) =>
          existingObj = @findWhere {_id:objData._id}
          if existingObj? then @remove existingObj

      # Extend sync to pass through the current document on read
      sync: (method, model, options) ->
        if method is "read" then options = _.extend options, {attrs:{_docId:@_docId}}
        Backbone.sync method, model, options

    class ConnectionCollection extends ObjectCollection
      model: ConnectionModel
      url: -> "/connections"

      initBroadcastCreate: ->
        @socket.on @url()+":create", (objData) =>
          @trigger "create:req", new @model objData, {parse:true}

    class NodeCollection extends ObjectCollection
      model: NodeModel
      url: -> "/nodes"

      initBroadcastDelete: ->
        @socket.on @url()+":delete", (objData) =>
          existingObj = @findWhere {_id:objData._id}
          if existingObj? then @trigger "remove:req", existingObj
          @map (n) -> n.fetch() #update other nodes on the workspace

    class WorkspaceModel extends Backbone.Model
      socket: io.connect("")
      urlRoot: -> "/workspace"

      defaults:
        _id: 0
        name: ""

      selectedColor: '#3498db'

      defaultColors:
          defaultHex: '#000' # not currently functional
          white: '#cdcdcd'
          red: '#E3A390'
          yellow: '#F2DB9D'
          green: '#B3E2B1'
          blue: '#B1CDE2'
          purple: '#E0B4E6'

      initialize: ->
        @socket = io.connect('')
        @socket.on @url()+":create", (workspaceData) =>
          @set workspaceData

        @nodes = new NodeCollection()
        @nodes.on "remove:req", (reqDelete) =>
          @removeNode reqDelete

        @connections = new ConnectionCollection()
        @connections.on "create:req", (reqCreate) =>
          # test to be sure connection is new
          if gm.connections.where({source:reqCreate.get('source'), target:reqCreate.get('target')}).length is 0
            # Fetch the source and target to update their new connection degrees
            @getSourceOf(reqCreate).fetch()
            @getTargetOf(reqCreate).fetch()
            @putConnection reqCreate

        @filterModel = new FilterModel()
        @nodes.on "change:tags", @updateFilter, this

        @documentModel = new DocumentModel()

      updateFilter: (node) ->
        @filterModel.set 'initial_tags', _.union(@filterModel.get('node_tags'), node.get('tags'))
        @filterModel.addNodeTags node.get('tags')

      setDocument: (doc) ->
        @documentModel = doc
        @nodes._docId = doc.id
        @connections._docId = doc.id
        @trigger "document:change"
        @socket.emit 'open:document', doc.attributes
        @connections.reset()
        $.when(@nodes.fetch()).then =>
          @connections.fetch()

      getDocument: ->
        @documentModel

      filter: =>
        nodesToRemove = @nodes.filter (node) =>
          !(@filterModel.passes node)
        @removeNode node for node in nodesToRemove

      # if called with nm, force:true the a node will be forced
      # through the filter, adding its tags to the filterModel
      putNode: (nodeModel, options) ->
        @nodes.add nodeModel
        nodeModel

      putNodeFromData: (data, options) ->
        node = new NodeModel data
        @putNode node, options

      # only put a connection when its source and target are on the wkspace
      putConnection: (connectionModel) ->
        sourceID = connectionModel.get 'source'
        targetId = connectionModel.get 'target'
        if @nodes.findWhere({_id:sourceID}) and @nodes.findWhere({_id:targetId})
          @connections.add connectionModel

      newConnectionCreated: (conn) ->
        @trigger 'create:connection', conn

      removeNode: (node) ->
        @connections.remove @connections.where {'source': node.get('_id')}
        @connections.remove @connections.where {'target': node.get('_id')}
        @nodes.remove node

      removeConnection: (model) ->
        @connections.remove model

      deleteNode: (model, callback) ->
        @removeNode model
        model.destroy
          success: callback

      deleteConnection: (model) ->
        @removeConnection model
        model.destroy()

      deSelect: (model, silent) ->
        if silent
          model.set {selected:false}, {silent:true}
        else
          model.set 'selected', false

      select: (model) ->
        @nodes.each (d) => @deSelect d, true
        @connections.each (d) => @deSelect d, true
        model.set 'selected', true

      getSourceOf: (connection) ->
        @nodes.findWhere _id: connection.get('source')

      getTargetOf: (connection) ->
        @nodes.findWhere _id: connection.get('target')

      highlight: (nodesToHL, connectionsToHL) ->
        @nodes.each (d) ->
          d.set 'dim', true
        _.each nodesToHL, (d) ->
          d.set 'dim', false
        @connections.each (d) ->
          d.set 'dim', true
        _.each connectionsToHL, (d) ->
          d.set 'dim', false
        @nodes.trigger "change"

      dehighlight: () ->
        @connections.each (d) ->
          d.set 'dim', false
        @nodes.each (d) ->
          d.set 'dim', false
        @nodes.trigger "change"

      getSpokes: (node) ->
        (@connections.where {'source': node.get('_id')}).concat @connections.where {'target': node.get('_id')}

      getFilter: () ->
        @filterModel

      getNodeNames: (cb) ->
        @documentModel.getNodeNames(cb)

      getTagNames: (cb) ->
        @documentModel.getTagNames(cb)

      getNodeByName: (name, cb) ->
        @documentModel.getNodeByName(name, cb)

      getNodesByTag: (tag, cb) ->
        @documentModel.getNodesByTag(tag, cb)

      getConnsByName: (name, cb) ->
        @documentModel.getConnsByName(name, cb)

      # Syncing Workspaces
      sync: (method, model, options) ->
        options = options || {}
        options.data = @serialize()
        options.contentType = 'application/json'
        Backbone.sync.apply(this, [method, model, options])

      serialize: ->
        nodes = @nodes.pluck "_id"
        connIds = @connections.pluck "_id"
        docId = @getDocument().get "_id"
        nodePositions = ({x:n.x,y:n.y,_id:n.get('_id')} for n in @nodes.models)
        serializedWorkspace =
          nodes: nodes
          connections: connIds
          nodeTags: @filterModel.get('node_tags')
          _id: this.get('_id')
          _docId: docId
          name: this.get('name')
          nodePositions: JSON.stringify(nodePositions)
          zoom: this.get('zoom')
          translate: this.get('translate')

      getWorkspace: (callback) ->
        @sync "read", this,
          success: callback

      deleteWorkspace: (id, callback) ->
        @socket.emit "workspace:destroy", {_id:id, _docId:@getDocument().get('_id')}
        callback id
