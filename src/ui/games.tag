<games>
  <div class="mdl-layout-spacer"></div>
  <game each={ games } data={ this } class="mdl-cell mdl-cell--6-col"></game>
  <div class="mdl-layout-spacer"></div>
  this.games = [
    {
      name: 'amorous',
      logo: 'logo_100.png'
    },
    {
      name: 'bbs',
      logo: 'bbs_logo_100.png'
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
      ongoingUpdates[arg.game].reject(arg);
    }
  });
  updateGame(game, launch) {
    console.log("Trying to update game " + game);
    var deffered = Q.defer();
    ongoingUpdates[game] = deffered;
    ipc.send('update-game', {game: game, launch: launch});

    return deffered.promise;
  }

  deleteGame(e) {
    console.log('Trying to delete: ' + e.item.name);
  }

  var promisedUpdates = {};
  ipc.on('update-check', function(arg){
    if(!arg.error) {
      promisedUpdates[arg.game].resolve(arg);
    } else {
      promisedUpdates[arg.game].reject(arg);
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
      Hello world!
    </div>
    <div if={ updateAvailable == 0 } class="mdl-card__actions mdl-card--border">
      Your game is up-to-date!
      <a class="mdl-button mdl-button--colored mdl-button--raised mdl-js-button mdl-js-ripple-effect pull-right" onclick={ parent.playGame }>
        Play!
      </a>
    </div>
    <div if={ updateAvailable == 1 && !updating } class="mdl-card__actions update-actions mdl-card--border">
      There is an update available!
      <label class="mdl-checkbox mdl-js-checkbox mdl-js-ripple-effect launch-check pull-right" for="{ name }-launch">
        <input type="checkbox" id="{ name }-launch" class="mdl-checkbox__input" checked={ launchASAP } onclick={ toggleLaunch } />
        <span class="mdl-checkbox__label">Launch when ready</span>
      </label>
      <a class="mdl-button mdl-button--colored mdl-button--raised mdl-js-button mdl-js-ripple-effect pull-right" onclick={ updateGame }>
        Update
      </a>
    </div>
    <div if={ updateAvailable == -1 } class="mdl-card__actions mld-card--border">
      Checking for updates...
    </div>
    <div show={ updating } class="mdl-card__actions mdl-card--border progress-holder">
      <div class="mdl-progress mdl-js-progress" id="{ name }-update-progress"></div>
    </div>
    <div class="mdl-card__menu">
      <button id="{ name }_card_more" class="mdl-button mdl-button--icon mdl-js-button mdl-js-ripple-effect">
        <i class="material-icons">more_vert</i>
      </button>
      <ul class="mdl-menu mdl-menu--bottom-right mdl-js-menu mdl-js-ripple-effect"
          for="{ name }_card_more">
        <li class="mdl-menu__item" onclick={ parent.deleteGame }>Delete Content</li>
      </ul>
    </div>
  </div>
  var vm = this;
  vm.updateAvailable = -1;
  vm.launchASAP = true;
  vm.updating = false;

  toggleLaunch(e) {
    vm.launchASAP = !vm.launchASAP;
  }

  updateGame(e) {
    vm.parent.updateGame(vm.name, vm.launchASAP).progress(function(progress) {
      document.querySelector('#' + vm.name + "-update-progress").MaterialProgress.setProgress(progress);
    }).then(function(res) {
      vm.updating = false;
      vm.update();
    });
    vm.updating = true;
    vm.update();
  }

  vm.on('mount', function(){
    vm.parent.checkForUpdate(vm.name).then(function(res){
      vm.updateAvailable = res.updateAvailable;
      vm.update();
    });
  });
</game>
