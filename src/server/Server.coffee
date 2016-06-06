require 'fluentnode'

FileStreamRotator = require('file-stream-rotator')

express           = require 'express'
load              = require 'express-load'
bodyParser        = require('body-parser');
d3                = require 'd3'
morgan            = require 'morgan'
pug               = require 'pug'
jsdom             = require 'jsdom'
cheerio           = require 'cheerio'
Routes            = require './Routes'
Redirects         = require './Redirects'

require 'fluentnode'

class Server
  constructor: (options)->
    @.app     = null
    @.options = options || {}
    @.server  = null
    @.port    = @.options.port || process.env.PORT || 3000

  setup_Server: =>    
    @.app = express()
    @.app.d3 = d3
    @.app.jsdom = jsdom
    @.app.set 'view engine', 'pug'
    @.app.engine('pug', pug.renderFile);

    #bodyParser
    @.app.use bodyParser.json()
    #@.app.use bodyParser.urlencoded extended: true

    #routes
    #@.app.get '/', @.route_Main
    #@.app.get '/'          , (req, res) => res.redirect 'd3-radar'
    @.app.get '/ping'      , (req, res) => res.end      'pong'
    #@.app.get '/d3-radar'  , (req, res) => res.render   'd3-radar'
    #@.app.get '/live-radar', (req, res) => res.render   'live-radar'
    #@.app.get '/test'      , (req, res) => res.render   'test'
    #@.app.get '/angular'   , (req, res) => res.render   'angular'
    @

  add_Bower_Support: ()=>
    #@.app.use('/lib',  express.static(__dirname + '../bower_components'));
    @.app.use '/lib',  express.static __dirname.path_Combine('../../bower_components')
    @.app.use '/ui',  express.static __dirname.path_Combine('../../src-ui/.dist')
    @

  add_Controllers: ->
    api_Path  = '/api/v1'
    view_Path = '/view'
    Api_File    = require '../controllers/Api-File'
    Api_Logs    = require '../controllers/Api-Logs'
    Api_Routes  = require '../controllers/Api-Routes'
    View_Routes = require '../controllers/View-Routes'
    View_File   = require '../controllers/View-File'
    View_Table  = require '../controllers/View-Table'

    @.app.use api_Path , new Api_Logs(   app:@.app).add_Routes().router
    @.app.use api_Path , new Api_File(   app:@.app).add_Routes().router
    @.app.use api_Path , new Api_Routes( app:@.app).add_Routes().router
    @.app.use view_Path, new View_Routes(app:@.app).add_Routes().router
    @.app.use view_Path, new View_File(  app:@.app).add_Routes().router
    @.app.use view_Path, new View_Table( app:@.app).add_Routes().router
    @
    
  add_Redirects: ->
    new Redirects(app:@.app).add_Redirects()
    @

  route_Main: (req, res) ->
    d3 = req.app.d3
    html = '<!doctype html><html></html>'
    document = req.app.jsdom.jsdom(html)

    svg = d3.select(document.body)
              .append('g')

    data = [3, 5, 8, 4, 7,];
    svg.selectAll('circle')
        .data(data)
        .enter()
        .append('circle')
        .attr('cx',  (d, i)->  (i + 1) * 100 - 50  )
        .attr('cy', svg.attr('height') / 2)
        .attr('r',  (d)-> d * 5)
    res.render 'index', svgstuff: svg.node().outerHTML


  setup_Logging: =>
    fs = require 'fs'
    @.logs_Folder  = __dirname.path_Combine('../../logs')
    console.log 'LOGS Folder: ' + @.logs_Folder
    if @.logs_Folder.folder_Not_Exists()      # note: docker was having a problem with the creation of this folder
      @.logs_Folder.folder_Create()           #       which is why this is now done on the Docker file (need to find root cause)

    @.logs_Options =
      date_format: 'YYYY_MM_DD-hh_mm',
      filename   : @.logs_Folder + '/logs-%DATE%.log',
      frequency  : '30m', 
      verbose    : false

    @.logs_Stream = FileStreamRotator.getStream @.logs_Options
    @.logs_Morgan = morgan 'combined', { stream: @.logs_Stream }
    @.app.use @.logs_Morgan


  start_Server: =>
    @.server = @.app.listen @.port
  
  server_Url: =>
    "http://localhost:#{@.port}"

  routes: =>    
    new Routes(app:@.app).list()
      
  run: (random_Port)=>
    if random_Port
      @.port = 23000 + 3000.random()
    @.setup_Server()
    @.setup_Logging()
    @.add_Bower_Support()
    @.add_Controllers()
    @.add_Redirects()
    @.start_Server()

  stop: (callback)=>
    if @.server
      @.server.close =>
        callback() if callback    

  get_Html: (virtual_Path, callback)->
    @.server_Url().add(virtual_Path).GET (data)->
      if data 
        $ = cheerio.load(data)
      callback $, data


module.exports = Server