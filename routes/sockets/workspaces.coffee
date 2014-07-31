url = process.env['GRAPHENEDB_URL'] || 'http://localhost:7474'
neo4j = require '../../node_modules/neo4j'
graphDb = new neo4j.GraphDatabase url
utils = require '../utils'

WorkspaceHelper = require '../helpers/WorkspaceHelper'
serverWorkspace = new WorkspaceHelper(graphDb)

# CREATE
exports.create = (data, callback, socket) ->
  console.log 'create workspace query requested', data
  newWorkspace = data
  serverWorkspace.create newWorkspace, (savedWorkspace) ->
    socket.emit('workspace:create', savedWorkspace)
    callback(null, savedWorkspace)

# READ
# exports.read = (data, callback, socket) ->
#   id = data._id
#   graphDb.getNodeById id, (err, node) ->
#     if err
#       console.error 'Something broke!', err
#     else
#       parsed = utils.parseNodeToClient node._data.data
#       socket.emit 'document:read', parsed
#       callback null, parsed
