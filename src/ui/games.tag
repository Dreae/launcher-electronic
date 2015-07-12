<games>
  <div class="mdl-layout-spacer"></div>
  <game each={ games } data={ this } class="mdl-cell mdl-cell--6-col"></game>
  <div class="mdl-layout-spacer"></div>
  this.games = [
    {
      name: 'amorous',
      logo: 'logo_100.png',
      description: "In-development furry dating game"
    },
    {
      name: 'bbs',
      logo: 'bbs_logo_100.png',
      description: "Feisty 3-button furry beat-em-up"
    }
  ];

  var Q = require('q');
  var ipc = require('ipc');

  var ongoingUpdates = {}
  ipc.on('update-progress', function(arg){
    if(!arg.error){
      if(!arg.done){
        ongoingUpdates[arg.game].notify(arg.progress);
      } else {
        ongoingUpdates[arg.game].resolve(arg);
      }
    } else {
      console.error(arg.error);
      ongoingUpdates[arg.game].reject(arg.error);
    }
  });
  updateGame(game) {
    var deffered = Q.defer();
    ongoingUpdates[game] = deffered;
    ipc.send('update-game', {game: game});

    return deffered.promise;
  }

  var launchingGames = {};
  ipc.on('game-launch', function(arg) {
    if(!arg.error) {
      launchingGames[arg.game].resolve(arg);
    } else {
      launchingGames[arg.game].reject(arg);
    }
  });
  launchGame(game) {
    var deffered = Q.defer();
    launchingGames[game] = deffered;
    ipc.send('launch-game', game);

    return deffered.promise;
  }

  var deletingGames = {};
  ipc.on('game-deleted', function(arg) {
    if(!arg.error) {
      deletingGames[arg.game].resolve(arg);
    } else {
      deletingGames[arg.game].reject(arg.error);
    }
  });
  deleteGame(game) {
    var deffered = Q.defer();
    deletingGames[game] = deffered;
    ipc.send('delete-game', game);
    return deffered.promise;
  }

  var promisedUpdates = {};
  ipc.on('update-check', function(arg){
    if(!arg.error) {
      promisedUpdates[arg.game].resolve(arg);
    } else {
      promisedUpdates[arg.game].reject(arg.error);
    }
  });
  checkForUpdate(game) {
    var deffered = Q.defer();
    promisedUpdates[game] = deffered;
    ipc.send('get-updates', game);

    return deffered.promise;
  }
</games>

<game>
  <div class="mdl-card mdl-shadow--2dp card-fill">
    <div class="mdl-card__title">
      <div class="mdl-layout-spacer"></div>
      <h6 class="mdl-card__title-text">
        <img src="static/img/{ logo }" alt={ name }/>
      </h6>
      <div class="mdl-layout-spacer"></div>
    </div>
    <div class="mdl-card__supporting-text">
      { description }
    </div>
    <div show={ updateAvailable == 0 && playable() } class="mdl-card__actions mdl-card--border">
      Your game is up-to-date!
      <a class="mdl-button mdl-button--colored mdl-button--raised mdl-js-button mdl-js-ripple-effect pull-right" onclick={ launchGame } disabled={ launching }>
        Play!
      </a>
    </div>
    <div show={ updateAvailable == 1 && !updating } class="mdl-card__actions update-actions mdl-card--border">
      There is an update available!
      <label class="mdl-checkbox mdl-js-checkbox mdl-js-ripple-effect launch-check pull-right" for="{ name }-launch">
        <input type="checkbox" id="{ name }-launch" class="mdl-checkbox__input" checked={ launchASAP } onclick={ toggleLaunch } />
        <span class="mdl-checkbox__label">Launch when ready</span>
      </label>
      <a class="mdl-button mdl-button--colored mdl-button--raised mdl-js-button mdl-js-ripple-effect pull-right" onclick={ updateGame }>
        Update
      </a>
    </div>
    <div if={ updateAvailable == -1 && !updateCheckError } class="mdl-card__actions mld-card--border update-single-action">
      Checking for updates...
    </div>
    <div if={ updateCheckError } class="mdl-card__actions mdl-card--border update-single-action">
      Unable to get updates: { updateCheckError }
      <a class="mdl-button mdl-button--colored mdl-button--raised mdl-js-button mdl-js-ripple-effect pull-right" onclick={ getUpdates }>
        Retry
      </a>
    </div>
    <div show={ updating && !updateError } class="mdl-card__actions mdl-card--border progress-holder">
      <div class="mdl-progress mdl-js-progress" id="{ name }-update-progress"></div>
    </div>
    <div if={ updating && updateError } class="mdl-card__actions mdl-card--border update-single-action">
      Error installing update: { updateError }
      <a class="mdl-button mdl-button--colored mdl-button--raised mdl-js-button mdl-js-ripple-effect pull-right" onclick={ updateGame }>
        Retry
      </a>
    </div>
    <div if={ deleting } class="mdl-card__actions mdl-card--border update-actions">
      Uninstalling...
    </div>
    <div class="mdl-card__menu">
      <button id="{ name }_card_more" class="mdl-button mdl-button--icon mdl-js-button mdl-js-ripple-effect">
        <i class="material-icons">more_vert</i>
      </button>
      <ul class="mdl-menu mdl-menu--bottom-right mdl-js-menu mdl-js-ripple-effect"
          for="{ name }_card_more">
        <li class="mdl-menu__item" onclick={ deleteGame }>Delete Content</li>
      </ul>
    </div>
  </div>
  var vm = this;
  vm.updateAvailable = -1;
  vm.launchASAP = true;
  vm.updating = false;
  vm.launching = false;
  vm.updateCheckError = null;
  vm.updateError = null;

  toggleLaunch(e) {
    vm.launchASAP = !vm.launchASAP;
  }

  playable() {
    return !updating && !launching && !updateError
  }

  launchGame(e) {
    vm.launching = true;
    vm.parent.launchGame(vm.name).then(function(res) {
      vm.launching = false;
      vm.update();
    });
    vm.update();
  }

  updateGame(e) {
    document.querySelector('#' + vm.name + "-update-progress").MaterialProgress.setProgress(0);
    vm.parent.updateGame(vm.name).progress(function(progress) {
      document.querySelector('#' + vm.name + "-update-progress").MaterialProgress.setProgress(progress);
    }).then(function(res) {
      document.querySelector('#' + vm.name + "-update-progress").MaterialProgress.setProgress(0);
      vm.updating = false;
      vm.updateAvailable = 0;
      vm.update();
      if(vm.launchASAP) {
        vm.launchGame(null);
      }
    }).catch(function(err) {
      vm.updateError = err;
      vm.updateAvailable = 0;
      vm.update();
    });
    vm.updating = true;
    vm.updateError = null;
    vm.update();
  }

  deleteGame(e) {
    vm.deleting = true;
    vm.update();
    vm.parent.deleteGame(vm.name).then(function(res) {
      vm.deleting = false;
      vm.getUpdates();
    }).catch(function(err){
      vm.deleting = false;
      console.log(err);
    })
  }

  getUpdates() {
    vm.parent.checkForUpdate(vm.name).then(function(res){
      vm.updateAvailable = res.updateAvailable;
      vm.updateCheckError = null;
      vm.update();
    }).catch(function(err) {
      vm.updateCheckError = err;
      vm.update();
    });
  }

  vm.on('mount', function(){
    vm.getUpdates();
  });
</game>
