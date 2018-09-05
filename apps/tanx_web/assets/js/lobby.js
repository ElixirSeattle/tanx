const JOIN_RETRY_INTERVAL = 200;
const JOIN_RETRY_COUNT = 10;
const REJOIN_RETRY_COUNT = 20;


class Lobby {

  constructor(socket) {
    this._playerName = "";
    this._socket = socket;
    this._gameId = null;
    this._gameChannel = null;
    this._joinPayload = null;
    this._joinCallbacks = [];
    this._leaveCallbacks = [];
    this._rejoinCallbacks = [];
    this._gameInfo = {};
    this._rejoinRetries = REJOIN_RETRY_COUNT;

    this._setupControls();

    this._setupGameList();

    $(window).on('beforeunload', () => {
      this.leave();
    });
  }


  leave() {
    $('#tanx-game-list').show();
    $('#tanx-game-info').hide();

    $('#game-name-span').text('');
    $('#game-node-span').text('');

    let backgroundMusic = $('#background-music')[0];
    backgroundMusic.pause();
    if (backgroundMusic.currentTime) {
      backgroundMusic.currentTime = "0";
    }

    if (this._gameId == null) return;

    let gameId = this._gameId;
    let gameChannel = this._gameChannel;
    this._gameChannel = null;
    this._gameId = null;
    this._joinPayload = null;
    this._leaveCallbacks.forEach(callback => {
      callback(gameId, gameChannel);
    });
    gameChannel.push('leave', {});
    gameChannel.leave();
  }


  onJoin(callback) {
    this._joinCallbacks.push(callback);
  }


  onRejoin(callback) {
    this._rejoinCallbacks.push(callback);
  }


  onLeave(callback) {
    this._leaveCallbacks.push(callback);
  }


  _setupControls() {
    let playerNameFieldJq = $('#tanx-name-field');
    let gameNameFieldJq = $('#tanx-game-name-field');

    $('#tanx-leave-btn').on('click', () => {
      this.leave();
    });
    $('#tanx-create-btn').on('click', () => {
      this._create(gameNameFieldJq.val());
    });

    gameNameFieldJq
      .off('keypress')
      .on('keypress', (event) => {
        if (event.which == 13) {
          this._create(gameNameFieldJq.val());
        }
      });

    playerNameFieldJq
      .off("keypress")
      .on('keypress', (event) => {
        if (event.which == 13) {
          playerNameFieldJq.blur();
          event.preventDefault();
        }
      })
      .on('change', (event) => {
        this._renamePlayer();
        event.stopPropagation();
      })
      .on('keydown', (event) => {
        event.stopPropagation();
      })
      .on('keyup', (event) => {
        event.stopPropagation();
      });

    this.leave();
  }


  _setupGameList() {
    this._lobbyChannel = this._socket.channel("lobby", {});

    let lobbyJoiner = this._lobbyChannel.join();

    this._lobbyChannel.on("update", update => {
      this._updateGameTable(update.g)
      $('#client-node-name').text(update.d);
      $('#client-build-id').text(update.b);
      this._gameInfo = {};
      update.g.forEach((game) => {
        this._gameInfo[game.i] = game;
        if (game.i == this._gameId) {
          $('#game-name-span').text(game.n || "(untitled game)");
          $('#game-node-span').text(game.d);
        }
      });
    });
    this._lobbyChannel.on("created", (meta) => {
      this._join(meta.id);
    });
  }


  _updateGameTable(games) {
    $('.tanx-game-row').remove();
    let createGameRow = $('#create-game-row');
    games.forEach(game => {
      $('<tr>').addClass("tanx-game-row")
        .append($('<td>').text(game.n || "(untitled game)"))
        .append($('<td>').text(game.d))
        .on('click', (event) => {
          this._join(game.i);
        })
        .insertBefore(createGameRow);
    });
  }


  _create(gameName) {
    if (this._gameId != null) return;
    this._lobbyChannel.push("create", {name: gameName});
  }


  _join(gameId) {
    if (this._gameId != null) return;

    this._joinGameWithRetry(gameId, JOIN_RETRY_COUNT);
  }


  _joinGameWithRetry(gameId, remaining) {
    if (remaining <= 0) return;

    let playerName = $('#tanx-name-field').val();
    let gameChannel = this._socket.channel("game:" + gameId, {name: playerName});
    gameChannel.onError(reason => {
      console.log("Received error on game channel");
      //this._gameChannel = null;
    });

    let gameJoiner = gameChannel.join();
    gameJoiner.receive("ok", reply => {
      this._joinPayload = gameJoiner.payload;
      this._gameChannel = gameChannel;
      if (this._gameId == null) {
        this._joinPayload.id = reply.i;
        this._finishJoin(reply.g);
      } else {
        this._finishRejoin(reply.g);
      }
      this._rejoinRetries = REJOIN_RETRY_COUNT;
    });
    gameJoiner.receive("error", reply => {
      if (this._gameId == null) {
        console.log("Error on join");
        gameChannel.leave();
        window.setTimeout(() => {
          this._joinGameWithRetry(gameId, remaining - 1);
        }, JOIN_RETRY_INTERVAL);
      } else {
        console.log("Error on rejoin");
        this._rejoinRetries--;
        if (reply.e == "player_not_found") {
          console.log("Leaving due to player not found");
          this.leave();
        } else if (this._rejoinRetries <= 0) {
          console.log("Leaving due to too many failed rejoins");
          this.leave();
        }
      }
    });
  }


  _finishJoin(game) {
    console.log("Joining game channel for game " + game.i);
    $('#game-name-span').text(game.n || "(untitled game)");
    $('#game-node-span').text(game.d);

    $('#tanx-game-list').hide();
    $('#tanx-game-info').show();

    this._gameId = game.i;
    this._joinCallbacks.forEach(callback => {
      callback(game.i, this._gameChannel);
    });
  }


  _finishRejoin(game) {
    console.log("Rejoining game channel for game " + game.i);
    this._rejoinCallbacks.forEach(callback => {
      callback(this._gameId, this._gameChannel);
    });
  }


  _renamePlayer() {
    let name = $('#tanx-name-field').val();

    if (name != this._playerName) {
      if (this._gameId != null) {
        this._gameChannel.push("rename", {name: name, old_name: this._playerName});
      }
      if (this._joinPayload != null) {
        this._joinPayload.name = name;
      }
      this._playerName = name
    }
  }

}


export default Lobby;
