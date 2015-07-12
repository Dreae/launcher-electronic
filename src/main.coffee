app = require('app');
BrowserWindow = require('browser-window');
updater = require('./launcher/updater');
fs = require('fs')

app.on 'ready', ->
  if process.platform == 'win32'
    fs.exists('7za.exe', (exists) ->
      if !exists
        fs.rename('resources/app/7za.exe', './7za.exe')
    )

  mainWindow = new BrowserWindow(
    width: 1080,
    height: 720,
    frame: false,
    resizable: false,
    'use-content-size': true
  );
  mainWindow.loadUrl('file://'+ __dirname + '/ui/index.html');

  mainWindow.on 'closed', ->
    app.quit();
