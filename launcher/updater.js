var https = require('https');
var http = require('http');
var fs = require('fs');
var q = require('q');
var zip = require('node-7z');
var mkdirp = require('mkdirp');
var child_process = require('child_process');

var updating = 0;
var playable = true;
var doneChunks = 0;
var totalChunks = 0;

function startUpdate(downloadUrl, start, game, build) {
  var promises = [];
  for(var c = 0; c < 3; c++) {
    if(c == downloadUrl.length) {
      break;
    }
    promises.push(getChunk(downloadUrl[c], c + start));
  }
  q.all(promises).then(function(){
    if(downloadUrl.length == 0){
      mergeAndExtract(game, build);
    } else {
      startUpdate(downloadUrl.slice(3), start + 3, game, build);
    }
  });
}

function mergeAndExtract(game, build) {
  fs.readdir('data', function(err, files) {
    var fd = fs.createWriteStream('data/data.7z', {flags: 'w+'});
    var concat = function(remaining) {
      if(remaining.length == 0) {
        fd.end();
        mkdirp('gamedata/' + game, function(err){
          updating = 3;
          new zip().extractFull('data/data.7z', 'gamedata/' + game).then(function() {
            updating = 0;
            fs.unlinkSync('data/data.7z')
            fs.writeFileSync('gamedata/'+game+'/version', String(build), {flag: 'w+'});
          }).catch(function(err){
            updating = -2;
          });
        });
        return;
      }

      var stream = fs.createReadStream('data/' + remaining[0]);
      stream.pipe(fd, {end: false});
      stream.on('end', function() {
        fs.unlink('data/' + remaining[0], function() {
          concat(remaining.slice(1));
        });
      });
    }

    var chunkList = [];
    for(var c = 0; c < files.length; c++){
      chunkList.push('chunk_' + c);
    }

    updating = 2;
    concat(chunkList);
  })
}

function getChunk(url, chunkNum){
  var defferred = q.defer();
  mkdirp('data', function(err){
    var fd = fs.createWriteStream('data/chunk_' + chunkNum, {flags: 'w+'});
    http.get(url, function(res){
      var stream = res.pipe(fd);
      res.on('end', function() {
        doneChunks++;
        defferred.resolve(true);
      });
    });
  });
  return defferred.promise;
}

function platform() {
  if(process.platform === 'darwin') {
    return 'mac';
  } else if(process.platform === 'win32') {
    return 'windows';
  } else if(process.platform === 'linux'){
    return 'linux';
  } else {
    return undefined;
  }
}

function getVersion(game) {
  var deffered = q.defer();
  fs.readFile('gamedata/'+game+'/version', {}, function(err, data) {
    if(err) {
      deffered.resolve(-1);
    } else {
      deffered.resolve(parseInt(data));
    }
  });
  return deffered.promise;
}

module.exports = {
  checkUpdate: function(game, callback) {
    getVersion(game).then(function(version) {
      https.get("https://download.amorousgame.com/api/v2/game/"+game+"/public/"+platform()+"/"+version, function(res){
        var data = '';
        res.on('data', function(chunk){
          data += chunk;
        });
        res.on('end', function(){
          var content = JSON.parse(data);
          if(content.updateAvailable) {
            totalChunks = content.downloadUrl[0].length;
            doneChunks = 0;
            startUpdate(content.downloadUrl[0], 0, game, content.build);
            updating = 1;
          }
          callback(content.updateAvailable);
        });
      }).on('error', function(e){
        updating = -1;
      });
    });
  },
  getStatus: function() {
    if(updating){
      switch (updating) {
        case 1:
          return "Downloading the latest version of the game, chunk " + doneChunks + "/" + totalChunks;
        case 2:
          return "Merging chunks";
        case 3:
          return "Extracting";
        case -2:
          return "Unable to extract archive";
        case -1:
          return "There was an error downloading";
      }
    } else{
      return "Your game is up-to-date";
    }
  },
  playable: function() {
    return !updating && playable;
  },
  launchGame: function(game) {
    if(platform() === 'windows') {
      var proc = child_process.spawn('gamedata/'+game+'/'+game+'.exe', [], {detached: true});
      proc.unref();
    }
  },
  platform: platform
}
