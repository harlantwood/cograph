define ['jquery', 'underscore', 'backbone', 'd3',
  'cs!views/ConnectionAdder', 'cs!views/TrashBin', 'cs!views/DataTooltip', 'cs!views/ZoomButtons'],
  ($, _, Backbone, d3, ConnectionAdder, TrashBin, DataTooltip, ZoomButtons) ->
    class GraphView extends Backbone.View
      el: $ '#graph'

      initialize: ->
        that = this
        @model.nodes.on 'add change remove', @update, this
        @model.connections.on 'add change remove', @update, this

        @translateLock = false

        width = $(@el).width()
        height = $(@el).height()

        @force = d3.layout.force()
                  .nodes([])
                  .links([])
                  .size([width, height])
                  .charge(-4000 )
                  .gravity(0.2)
                  .friction(0.6)

        zoomed = =>
          return if @translateLock
          @workspace.attr "transform",
            "translate(#{d3.event.translate}) scale(#{d3.event.scale})"
        @zoom = d3.behavior.zoom().on('zoom', zoomed)

        # ignore panning and zooming when dragging node
        @translateLock = false
        # store the current zoom to undo changes from dragging a node
        currentZoom = undefined
        @force.drag()
        .on "dragstart", (d) ->
          that.translateLock = true
          currentZoom = that.zoom.translate()
          d3.select(this).classed("fixed", d.fixed = true)
        .on "drag", (d)=>
          if @isContainedIn d, $('#trash-bin')
            $("#trash-bin").addClass('selected')
          else
            $("#trash-bin").removeClass('selected')
        .on "dragend", (node) =>
          @trigger "node:dragend", node
          @zoom.translate currentZoom
          @translateLock = false

        @svg = d3.select(@el).append("svg:svg")
                .attr("pointer-events", "all")
                .attr('width', width)
                .attr('height', height)
                .call(@zoom)
                .on("dblclick.zoom", null)

        #Per-type markers, as they dont inherit styles.
        @svg.append("defs").append("marker")
            .attr("id", "arrowhead")
            .attr("viewBox", "0 -5 10 10")
            .attr("refX", 16)
            .attr("refY", 0)
            .attr("markerWidth", 3)
            .attr("markerHeight", 3)
            .attr("orient", "auto")
            .attr("fill", "gray")
            .attr("stroke","white")
            .attr("stroke-width","4px")
            .attr("stroke-location","outside")
            .append("path")
              .attr("d", "M0,-5L10,0L0,5")

        @svg.append("defs").append("marker")
            .attr("id", "draghead")
            .attr("viewBox", "0 -5 10 10")
            .attr("refX", 5)
            .attr("refY", 0)
            .attr("markerWidth", 3)
            .attr("markerHeight", 3)
            .attr("orient", "auto")
            .attr("fill", "black")
            .append("path")
              .attr("d", "M0,-5L10,0L0,5")

        @workspace = @svg.append("svg:g")
        @workspace.append("svg:g").classed("connection-container", true)
        @workspace.append("svg:g").classed("node-container", true)

        @connectionAdder = new ConnectionAdder
          model: @model
          attributes: {force: @force, svg: @svg, graphView: this}

        @trashBin = new TrashBin
          model: @model
          attributes: {graphView: this}

        @dataTooltip = new DataTooltip
          model: @model
          attributes: {graphView: this}

        @zoomButtons = new ZoomButtons
          attributes: {zoom: @zoom, workspace: @workspace}

      update: ->
        that = this
        nodes = @model.nodes.models
        connections = @model.connections.models
        @force.nodes(nodes).links(_.pluck(connections,'attributes')).start()

        connection = d3.select(".connection-container")
          .selectAll(".connection")
          .data connections
        connectionEnter = connection.enter().append("line")
          .attr("class", "connection")
          .attr("marker-end", "url(#arrowhead)")

        # old elements
        node = d3.select(".node-container")
          .selectAll(".node")
          .data(nodes, (node) -> node.cid)

        # new elements
        nodeEnter = node.enter().append("g")
        nodeEnter.append("text")
          .attr("dy", "40px")
        nodeEnter.append("circle")
          .attr("r", 25)

        connectionEnter
        .on "click", (d) =>
          @model.selectConnection d
        .on "mouseover", (datum, index)  =>
          if !@dataToolTipShown
            @isHoveringANode = setTimeout( () =>
              @dataToolTipShown = true
              $(".data-tooltip-container")
                .append _.template(dataTooltipTemplate, datum)
            ,200)
        .on "mouseout", (datum, index) =>
          window.clearTimeout(@isHoveringANode)
          @dataToolTipShown = false
          $(".data-tooltip-container").empty()

        nodeEnter
        .on "dblclick", (d) ->
          d3.select(this).classed("fixed", d.fixed = false)
        .on "click", (d) =>
          if (d3.event.defaultPrevented)
            return
          @model.selectNode d
        .on "contextmenu", (d) =>
          d3.event.preventDefault()
          @trigger 'node:right-click', d

        .on "mouseover", (node) =>
          if @creatingConnection then return
          @trigger "node:mouseover", node

          connectionsToHL = @model.connections.filter (c) ->
            (c.get('source').cid is node.cid) or (c.get('target').cid is node.cid)

          nodesToHL = _.flatten connectionsToHL.map (c) -> [c.get('source'), c.get('target')]
          nodesToHL.push node

          @model.highlightNodes(nodesToHL)
          @model.highlightConnections(connectionsToHL)
        .on "mouseout", (node) =>
          @trigger "node:mouseout", node

        # update old and new elements
        node.attr('class', 'node')
          .classed('dim', (d) -> d.get('dim'))
          .classed('selected', (d) -> d.get('selected'))
          .classed('fixed', (d) -> d.fixed)
          .call(@force.drag)
        node.select('text')
          .text((d) -> d.get('name'))

        connection.attr("class", "connection")
          .classed('dim', (d) -> d.get('dim'))
          .classed('selected', (d) -> d.get('selected'))

        # delete unmatching elements
        node.exit().remove()
        connection.exit().remove()

        tick = =>
          connection
            .attr("x1", (d) -> d.attributes.source.x)
            .attr("y1", (d) -> d.attributes.source.y)
            .attr("x2", (d) -> d.attributes.target.x)
            .attr("y2", (d) -> d.attributes.target.y)
          node.attr("transform", (d) -> "translate(#{d.x},#{d.y})")
          @connectionAdder.tick()
        @force.on "tick", tick

      isContainedIn: (node, element) ->
        node.x < element.offset().left + element.width() &&
          node.x > element.offset().left &&
          node.y > element.offset().top &&
          node.y < element.offset().top + element.height()
