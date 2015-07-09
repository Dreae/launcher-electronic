var express = require('express');
var bodyParser = require('body-parser');
var updater = require('./updater');

var game = 'bbs';

module.exports = function(mainWindow) {
  var app = express();
  app.use(function(req, res, next){
    res.set('Access-Control-Allow-Origin', '*');
    req.headers['content-type'] = 'application/json';
    next();
  });
  app.use(bodyParser.json());

  app.get('/checklauncher', function(req, res){
    res.json({});
  });

  app.get('/getstatus', function(req, res){
    res.json({
      "BlockingError": false,
      "ReadyLogin": true,
      "ReadyPlay": updater.playable(),
      "Status": updater.getStatus(),
      "Progress": 0.0
    });
  });

  app.post('/checklogin', function(req, res){
    var body = req.body;
    game = body.game;
    updater.checkUpdate(game, function(updateAvailable){
      readyPlay = !updateAvailable;
      res.json({
        "error": false,
        "errorMessage": "Access authorized!",
        "updateAvailable": updateAvailable,
        "build": 0,
        "downloadUrl": null
      })
    })
  });

  app.get('/play', function(req, res) {
    updater.launchGame(game);
    res.json({});
  });

  app.get('/closelauncher', function(req,res){
    mainWindow.close();
  });
  return app;
};
