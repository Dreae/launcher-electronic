var app = require('app');
var BrowserWindow = require('browser-window');

app.on('ready', function() {
  var mainWindow = new BrowserWindow({
    width: 1080,
    height: 720,
    frame: true,
    resizable: false,
    'node-integration': false,
    'use-content-size': true
  });
  require('./launcher/http')(mainWindow).listen(1989, "127.0.0.1");
  
  mainWindow.loadUrl('http://launcher.amorousgame.com/v2/');

  mainWindow.on('closed', function() {
    app.quit();
  });
})
