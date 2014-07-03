express = require 'express.io'
path = require 'path'
favicon = require 'static-favicon'
bodyParser = require 'body-parser'
routes = require './routes/index'

app = express()

app.set 'views', __dirname + '/app/public'
app.set 'view engine', 'jade'

app.use favicon(path.join(__dirname, '/app/assets/images/rhizi.ico'))
app.use require('less-middleware')(path.join(__dirname, '/app/') )
app.use bodyParser()

# this line must be after the less-middleware declaration
# http://stackoverflow.com/questions/19489681/node-js-less-middleware-not-auto-compiling
app.use express.static(path.join(__dirname, '/app'))

app.use '/', routes

module.exports = app
