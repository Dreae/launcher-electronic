app = require('app');
BrowserWindow = require('browser-window');
updater = require('./launcher/updater');

app.on 'ready', ->
  mainWindow = new BrowserWindow(
    width: 1080,
    height: 720,
    frame: false,
    resizable: false,
    'use-content-size': true
  );
  mainWindow.openDevTools();
  mainWindow.loadUrl('file://'+ __dirname + '/ui/index.html');

  mainWindow.on 'closed', ->
    app.quit();
