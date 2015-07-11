app = require('app');
BrowserWindow = require('browser-window');

app.on 'ready', ->
  mainWindow = new BrowserWindow(
    width: 1080,
    height: 720,
    frame: true,
    resizable: false,
    'node-integration': false,
    'use-content-size': true
  );

  mainWindow.loadUrl('http://launcher.amorousgame.com/v2/');

  mainWindow.on 'closed', ->
    app.quit();
