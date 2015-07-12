ipc = require('ipc')
Q = require('q')
https = require('https')
http = require('http')
mkdirp = require('mkdirp')
fs = require('fs')
zip = require('node-7z')
child_process = require('child_process')
rimraf = require('rimraf')

ipc.on 'get-updates', (event, arg) ->
    checkUpdate(arg).then((updateAvailable) ->
      event.sender.send 'update-check',
        game: arg
        updateAvailable: updateAvailable
        error: false
    ).catch((error) ->
      event.sender.send 'update-check',
        game: arg
        updateAvailable: -1
        error: error
    )

ipc.on 'update-game', (event, req) ->
  updateGame(req.game).progress((progress) ->
    event.sender.send 'update-progress',
      done: false
      error: false
      game: req.game
      progress: progress
  ).then((res) ->
    event.sender.send 'update-progress',
      done: true
      error: false
      game: req.game
      progress: 100
  ).catch((err) ->
    event.sender.send 'update-progress',
      done: false
      error: err
      game: req.game
      progress: 0
  )

ipc.on 'launch-game', (event, game) ->
  launchGame(game).then(->
    event.sender.send 'game-launch',
      game: game
      error: false
  ).catch((err) ->
    event.sender.send 'game-launch',
      game: game
      error: err
  )

ipc.on 'delete-game', (event, game) ->
  deleteGame(game).then(->
    event.sender.send 'game-deleted',
      game: game
      error: false
  ).catch((err) ->
    event.sender.send 'game-deleted',
      game: game
      error: err
  )

platform = () ->
  if process.platform == 'darwin'
    'mac'
  else if process.platform == 'win32'
    'windows'
  else if process.platform == 'linux'
    'linux'
  else
    undefined

checkUpdate = (game) ->
  deffered = Q.defer()
  getVersion(game).then (version) ->
    https.get("https://download.amorousgame.com/api/v2/game/#{game}/public/#{platform()}/#{version}", (res) ->
      data = ''
      res.on 'data', (chunk) ->
        data += chunk

      res.on 'end', () ->
        if res.statusCode != 200
          deffered.reject "Got status code #{res.statusCode} from API"
        else
          content = JSON.parse(data);
          if content.updateAvailable
            deffered.resolve(1)
          else
            deffered.resolve(0)
    ).on 'error', (err) ->
      deffered.reject "Unable to connect to API"

  deffered.promise

getVersion = (game) ->
  deffered = Q.defer()
  fs.readFile "gamedata/#{game}/version.txt", {}, (err, data) ->
    if err
      deffered.resolve -1
    else
      deffered.resolve parseInt(data)
  return deffered.promise

updateGame = (game) ->
  deffered = Q.defer()
  getVersion(game).then (version) ->
    https.get("https://download.amorousgame.com/api/v2/game/#{game}/public/#{platform()}/#{version}", (res) ->
      data = ''
      res.on 'data', (chunk) ->
        data += chunk

      res.on 'end', () ->
        if res.statusCode != 200
          deffered.reject
            status: res.statusCode
            url: res.url
        else
          content = JSON.parse(data);
          if content.error
            deffered.reject
              status: res.statusCode
              url: res.url
              msg: content.errorMessage
            return

          totalChunks = content.downloadUrl[0].length;
          fetchChunks(content.downloadUrl[0]).progress((chunksDone) ->
            deffered.notify (chunksDone / totalChunks) * 100
          ).then(-> mergeAndExtract(game, content.build)).then(->
            deffered.resolve()
          ).catch((err) ->
            deffered.reject(err);
          )

    ).on 'error', (err) ->
      deffered.reject("Unable to get update data")

  deffered.promise

fetchChunks = (downloadUrls) ->
  deffered = Q.defer()
  done = 0

  blocks = for i in [0..2]
    (c for c in [0..downloadUrls.length - 1] when c % 3 == i)

  promises = for block in blocks
    runBlock downloadUrls, block

  Q.all(promises).then(->
    deffered.resolve()
  ).progress(->
    done++
    deffered.notify(done)
  ).catch((err) ->
    deffered.reject(err);
  )

  deffered.promise

runBlock = (downloadUrls, block) ->
  bd = Q.defer()
  runBlock_ = (ci) ->
    getChunk(downloadUrls[block[ci]], block[ci]).then(->
      bd.notify()
      if ci + 1 != block.length
        runBlock_(ci + 1)
      else
        bd.resolve()
    ).catch((err) ->
      bd.reject(err)
    )
  runBlock_ 0
  bd.promise

getChunk = (url, number) ->
  deffered = Q.defer()
  mkdirp 'data', (err) ->
    fd = fs.createWriteStream("data/chunk_#{number}", {flags: 'w+'})
    http.get(url, (res) ->
      stream = res.pipe(fd)
      res.on 'end', ->
        deffered.resolve()
    ).on('error', (err) ->
      fd.end()
      deffered.reject("Error getting chunk #{number}")
    )
  deffered.promise

mergeAndExtract = (game, build) ->
  deffered = Q.defer()
  fs.readdir 'data', (err, files) ->
    fd = fs.createWriteStream 'data/data.7z', {flags: 'w+'}
    concat = (remaining) ->
      if remaining.length == 0
        fd.end()
        mkdirp "gamedata/#{game}", (err) ->
          new zip().extractFull('data/data.7z', "gamedata/#{game}").then(->
            fs.unlink('data/data.7z', ->
              fs.writeFile("gamedata/#{game}/version.txt", String(build), {flag: 'w+'}, (err) ->
                if err
                  deffered.reject("Error writing version file")
                else
                  deffered.resolve()
              )
            )
          ).catch((err) ->
            deffered.reject("Cannot extract files")
          )
        return
      stream = null
      try
        stream = fs.createReadStream("data/#{remaining[0]}")
      catch err
        deffered.reject(err)
        return
      stream.pipe(fd, {end: false})
      stream.on 'end', ->
        fs.unlink "data/#{remaining[0]}", ->
          concat(remaining[1..])

    chunkList = for c in [0..files.length - 1]
      "chunk_#{c}"
    concat(chunkList)

  return deffered.promise

launchGame = (game) ->
  deffered = Q.defer()
  if platform() == 'windows'
    proc = child_process.spawn "gamedata/#{game}/#{game}.exe", [], {detached: true}
    proc.unref();
    deffered.resolve()
  else
    deffered.reject("Platform not supported")
  deffered.promise


deleteGame = (game) ->
  deffered = Q.defer()
  rimraf("gamedata/#{game}", (err) ->
    if err
      deffered.reject(err)
    else
      deffered.resolve()
  )
  deffered.promise
