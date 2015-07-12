ipc = require('ipc')
Q = require('q')
https = require('https')
http = require('http')
mkdirp = require('mkdirp')
fs = require('fs')

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
  https.get("https://download.amorousgame.com/api/v2/game/#{game}/public/#{platform()}/-1", (res) ->
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
        if content.updateAvailable
          deffered.resolve(1)
        else
          deffered.resolve(0)
  ).on 'error', deffered.reject

  deffered.promise

updateGame = (game) ->
  deffered = Q.defer()
  https.get("https://download.amorousgame.com/api/v2/game/#{game}/public/#{platform()}/-1", (res) ->
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

  ).on 'error', deffered.reject

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
    )
  deffered.promise
