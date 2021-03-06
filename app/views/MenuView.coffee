define ['jquery', 'underscore', 'backbone', 'bloodhound', 'typeahead', 'bootstrap',
 'text!templates/new_doc_modal.html', 'text!templates/open_doc_modal.html',
 'text!templates/analytics_modal.html', 'text!templates/workspaces_menu_modal.html',
 'cs!models/DocumentModel', 'socket-io', 'text!templates/graph_settings.html','text!templates/description_box.html', 'text!templates/import_tweets_modal.html'],
  ($, _, Backbone, Bloodhound, typeahead, bootstrap, newDocTemplate, openDocTemplate, analyticsTemplate, workspacesMenuTemplate, DocumentModel, io, openSettingsTemplate, descriptionTemplate, importTweetsTemplate) ->
    class DocumentCollection extends Backbone.Collection
      model: DocumentModel
      url: 'documents'
      socket: io.connect('')

    class MenuView extends Backbone.View
      el: $ 'body'

      events:
        'click #new-doc-button': 'newDocumentModal'
        'click #open-doc-button': 'openDocumentModal'
        'click #analytics-button': 'openAnalyticsModal'
        'click #workspaces-button': 'openWorkspacesModal'
        'click #settings-button': 'openSettingsModal'
        'click .public-button-display': 'openSettingsModal'
        'click #save-graph-settings': 'saveSettings'
        'click .public-button-view': 'publicViewChange'
        'click .public-button-edit': 'publicEditChange'
        'click #maybe-publish-button': 'openSettingsModal'
        'blur #description': 'saveDescription'
        'click #description-toggle': 'toggleDescription'
        'click #import-tweets-button': 'openImportTweetsModal'

      initialize: ->
        @loadBBModal()
        @model.on "document:change", @render, this
        @model.getDocument().on 'change', @render, this
        @model.getDocument().on 'change:public', @updatePublicButton, this
        @render()

      render: ->
        @updateTitle()
        @updatePublicButton()
        @updatePublishButton()
        editable = @model.getDocument().get('publicEdit') > 0 or _.contains(window.user.documents, @model.getDocument().get('_id'))
        $('#description').html _.template(descriptionTemplate, {description:@model.getDocument().get('description'), editable:editable})

      updatePublishButton: ->
        if @model.getDocument().get("publicView") is 0 or @model.getDocument().get("publicView") is 1
          $('#maybe-publish-button').html "<a class='clickable'>Publish</a>"
        else if($('.public-button-display').hasClass('clickable')) #isOwner
          $('#maybe-publish-button').html "<a class='clickable'>Settings</a>"
        else 
          $('#maybe-publish-button').html ""

      newDocumentModal: ->
        @newDocModal = new Backbone.BootstrapModal(
          content: _.template(newDocTemplate, {})
          title: "New Cograph"
          animate: true
          showFooter: false
        ).open()

        @newDocModal.on "shown", () ->
          $('#newDocName').focus()
          $("#new-doc-form").submit (e) ->
            false

        $('#new-doc-form', @newDocModal.$el).click () =>
          @newDocument()
          @newDocModal.close()

      newDocument: () ->
        docName = $('#newDocName', @newDocModal.el).val()
        newDocument = new DocumentModel(name: docName)
        $.when(newDocument.save()).then =>
          if window.user?
            name = window.user.local.name
            window.open "/#{name}/document/"+newDocument.get('_id'), "_blank"
          else
            window.open '/'+newDocument.get('_id'), "_blank"

      openImportTweetsModal: ->
        @importTweetsModal = new Backbone.BootstrapModal(
          content: _.template(importTweetsTemplate, {})
          title: "Import tweets"
          animate: true
          showFooter: false
        ).open()

        @importTweetsModal.on "shown", () ->
          $('#twitterQueryInput').focus()
          $('#twitter-query-form').submit (e) ->
            #@importTweets $('#twitterQueryInput').val() $('#twitterQuerySlider').val()

      importTweets: (query, num) ->
        # gets the tweets
        # make a request to https://api.twitter.com/1.1/search/tweets.json
        # q: query
        # count: # max 100
        false
      openSettingsModal: ->
        if($('.public-button-display').hasClass('clickable')) #isOwner
          name = @model.getDocument().get("name")
          canPublicView = @model.getDocument().get("publicView")
          canPublicEdit = @model.getDocument().get("publicEdit")
          @openSettingsModal = new Backbone.BootstrapModal(
            content: _.template(openSettingsTemplate, {name:name, canPublicView:canPublicView, canPublicEdit:canPublicEdit, embed:@getEmbed(window.location.href)})
            title: "Graph Settings"
            animate: true
            showFooter: false
          ).open()

      publicViewChange: (e) ->
        $('.public-button-view').removeClass('selected')
        $(e.currentTarget).addClass('selected')

      publicEditChange: (e) ->
        $('.public-button-edit').removeClass('selected')
        $(e.currentTarget).addClass('selected')

      saveSettings: ->
        doc = @model.getDocument()
        doc.set 'name', $('#settings-menu-title').val()
        newViewState = $('.public-button-view.selected').data('type')
        newEditState = $('.public-button-edit.selected').data('type')
        doc.set "publicView", newViewState
        doc.set "publicEdit", newEditState
        doc.save()
        @openSettingsModal.close()
        @updateTitle()
        @updatePublicButton()
        @updatePublishButton()

      saveDescription: ->
        @model.getDocument().set 'description', $.trim($('#editable').text())
        @model.getDocument().save()

      toggleDescription: ->
        $('#description-toggle > i').toggleClass('fa-rotate-180')
        $('#description > section').toggle()

      updatePublicButton: ->
        if @model.getDocument().get('publicView') != 0
          $('.public-button-display').html '<i class="fa fa-globe" title="public"></i>'
        else
          $('.public-button-display').html '<i class="fa fa-lock" title="private"></i>'

      updateTitle: ->
        $('#menu-title-display').text @model.getDocument().get('name')
        $('.navbar-doc-title').css('left', 'calc(50% - '+$(".navbar-doc-title").width()/2+'px')

      # NOTE: THIS IS CURRENTLY UNUSED
      openDocumentModal: ->
        user = window.user
        documents = new DocumentCollection
        if user?
          data = {documentIds: user.documents}
        else
          data = {}
        $.when(documents.fetch({data: data})).then =>
          modal = new Backbone.BootstrapModal(
            content: _.template(openDocTemplate, {documents: documents})
            title: "Open Cograph"
            animate: true
            showFooter: false
          ).open()
        false # prevent navigation from appending '#'

      openAnalyticsModal: ->
        @model.getDocument().getAnalytics (analyticsData) ->
          modal = new Backbone.BootstrapModal(
            content: _.template(analyticsTemplate, analyticsData)
            title: "Stats"
            animate: true
            showFooter: false
          ).open()
        false # prevent navigation from appending '#'

      getEmbed: (url) ->
        """
          <div style="width: 100%;margin: 0px auto">
            <div style='height: 0;width: 100%;padding-bottom: 57.5%;
            overflow: hidden;position: relative;'>
              <iframe src='#{url}' style="width: 100%;height: 100%;position: absolute;top: 0;left: 0;"
              scrolling='no' frameborder='0' allowfullscreen>
              </iframe>
            </div>
          </div>
        """

      openWorkspacesModal: ->
        docId = @model.getDocument().get("_id")
        workspaces = @model.getDocument().get("workspaces")
        createdBy = @model.getDocument().get("createdBy")
        modal = new Backbone.BootstrapModal(
          content: _.template(workspacesMenuTemplate, {docId:docId, workspaces:workspaces, createdBy: createdBy})
          title: "Open View"
          animate: true
          showFooter: false
        ).open()

        modal.on 'shown', () =>
          $('.delete-workspace').on 'click', (e) =>
            e.preventDefault()
            @model.deleteWorkspace $(e.currentTarget).attr('data-id'), (id) =>
              modal.close()

        false # prevent navigation from appending '#'

      loadBBModal: ->
        ###*
        Bootstrap Modal wrapper for use with Backbone.

        Takes care of instantiation, manages multiple modals,
        adds several options and removes the element from the DOM when closed

        @author Charles Davison <charlie@powmedia.co.uk>

        Events:
        shown: Fired when the modal has finished animating in
        hidden: Fired when the modal has finished animating out
        cancel: The user dismissed the modal
        ok: The user clicked OK
        ###
        (($, _, Backbone) ->
          
          #Set custom template settings
          _interpolateBackup = _.templateSettings
          _.templateSettings =
            interpolate: /\{\{(.+?)\}\}/g
            evaluate: /<%([\s\S]+?)%>/g

          template = _.template("""
            <div class=\"modal-dialog\">
              <div class=\"modal-content\">
                <% if (title) { %>
                <div class=\"modal-header\">
                  <% if (allowCancel) { %>
                  <a class=\"close\">&times;</a>
                  <% } %>
                  <h4>{{title}}</h4>
                </div>
                <% } %>
              <div class=\"modal-body\">{{content}}</div>
              <% if (showFooter) { %>
                <div class=\"modal-footer\">
                  <% if (allowCancel) { %>
                    <% if (cancelText) { %>
                      <a href=\"#\" class=\"btn cancel\">{{cancelText}}</a>
                    <% } %>
                  <% } %>
                  <a href=\"#\" class=\"btn ok btn-primary\">{{okText}}</a>
                </div>
              <% } %>
              </div>
            </div>
            """)
          
          #Reset to users' template settings
          _.templateSettings = _interpolateBackup
          Modal = Backbone.View.extend(
            className: "modal"
            events:
              "click .close": (event) ->
                event.preventDefault()
                @trigger "cancel"
                @options.content.trigger "cancel", this  if @options.content and @options.content.trigger

              "click .cancel": (event) ->
                event.preventDefault()
                @trigger "cancel"
                @options.content.trigger "cancel", this  if @options.content and @options.content.trigger

              "click .ok": (event) ->
                event.preventDefault()
                @trigger "ok"
                @options.content.trigger "ok", this  if @options.content and @options.content.trigger
                @close()  if @options.okCloses

              keypress: (event) ->
                if @options.enterTriggersOk and event.which is 13
                  event.preventDefault()
                  @trigger "ok"
                  @options.content.trigger "ok", this  if @options.content and @options.content.trigger
                  @close()  if @options.okCloses
            
            ###*
            Creates an instance of a Bootstrap Modal
            ###
            initialize: (options) ->
              @options = _.extend(
                title: null
                okText: "OK"
                focusOk: true
                okCloses: true
                cancelText: "Cancel"
                showFooter: true
                allowCancel: true
                escape: true
                animate: false
                template: template
                enterTriggersOk: false
              , options)
            
            ###*
            Creates the DOM element
            ###
            render: ->
              $el = @$el
              options = @options
              content = options.content
              
              #Create the modal container
              $el.html options.template(options)
              $content = @$content = $el.find(".modal-body")
              
              #Insert the main content if it's a view
              if content and content.$el
                content.render()
                $el.find(".modal-body").html content.$el
              $el.addClass "fade"  if options.animate
              @isRendered = true
              this

            ###*
            Renders and shows the modal            
            @param {Function} [cb]     Optional callback that runs only when OK is pressed.
            ###
            open: (cb) ->
              @render()  unless @isRendered
              self = this
              $el = @$el
              
              #Create it
              $el.modal _.extend(
                keyboard: @options.allowCancel
                backdrop: (if @options.allowCancel then true else "static")
              , @options.modalOptions)
              
              #Focus OK button
              $el.one "shown.bs.modal", ->
                $el.find(".btn.ok").focus()  if self.options.focusOk
                self.options.content.trigger "shown", self  if self.options.content and self.options.content.trigger
                self.trigger "shown"

              #Adjust the modal and backdrop z-index; for dealing with multiple modals
              numModals = Modal.count
              $backdrop = $(".modal-backdrop:eq(" + numModals + ")")
              backdropIndex = parseInt($backdrop.css("z-index"), 10)
              elIndex = parseInt($backdrop.css("z-index"), 10)
              $backdrop.css "z-index", backdropIndex + numModals
              @$el.css "z-index", elIndex + numModals
              if @options.allowCancel
                $backdrop.one "click", ->
                  self.options.content.trigger "cancel", self  if self.options.content and self.options.content.trigger
                  self.trigger "cancel"

                $(document).one "keyup.dismiss.modal", (e) ->
                  e.which is 27 and self.trigger("cancel")
                  e.which is 27 and self.options.content.trigger("shown", self)  if self.options.content and self.options.content.trigger

              @on "cancel", ->
                self.close()

              Modal.count++
              
              #Run callback on OK if provided
              self.on "ok", cb  if cb
              this
            
            ###*
            Closes the modal
            ###
            close: ->
              self = this
              $el = @$el
              
              #Check if the modal should stay open
              if @_preventClose
                @_preventClose = false
                return
              $el.one "hidden.bs.modal", onHidden = (e) ->
                
                # Ignore events propagated from interior objects, like bootstrap tooltips
                return $el.one("hidden", onHidden)  if e.target isnt e.currentTarget
                self.remove()
                self.options.content.trigger "hidden", self  if self.options.content and self.options.content.trigger
                self.trigger "hidden"
                return

              $el.modal "hide"
              Modal.count--
              return
            
            ###*
            Stop the modal from closing.
            Can be called from within a 'close' or 'ok' event listener.
            ###
            preventClose: ->
              @_preventClose = true
              return
          ,
            
            #STATICS            
            #The number of modals on display
            count: 0
          )
          
          #Regular; add to Backbone.Bootstrap.Modal
          #else
          Backbone.BootstrapModal = Modal
        ) jQuery, _, Backbone
