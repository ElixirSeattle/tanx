
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

    this._setupControls();

    this._setupGameList();
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
    $('#tanx-leave-btn').on('click', () => {
      this._leave();
    });
    $('#tanx-create-btn').on('click', () => {
      this._create($('#tanx-game-name-field').val());
    });

    let nameFieldJq = $('#tanx-name-field');
    nameFieldJq
      .off("keypress")
      .on('keypress', (event) => {
        if (event.which == 13) {
          nameFieldJq.blur();
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

    this._leave();
  }


  _setupGameList() {
    this._lobbyChannel = this._socket.channel("lobby", {});

    let lobbyJoiner = this._lobbyChannel.join();

    this._lobbyChannel.on("update", update => {
      this._updateGameTable(update.g)
      $('#client-node-name').text(update.d);
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

    this._joinGameWithRetry(gameId, 10);
  }


  _joinGameWithRetry(gameId, remaining) {
    if (remaining <= 0) return;

    let playerName = $('#tanx-name-field').val();
    let gameChannel = this._socket.channel("game:" + gameId, {name: playerName});
    gameChannel.onError(reason => {
      console.log("received error on game channel");
      this._gameChannel = null;
    });

    let gameJoiner = gameChannel.join();
    gameJoiner.receive("ok", reply => {
      this._joinPayload = gameJoiner.payload;
      this._gameChannel = gameChannel;
      if (this._gameId == null) {
        gameJoiner.payload.id = reply.i;
        this._finishJoin(gameId);
      } else {
        this._finishRejoin();
      }
    });
    gameJoiner.receive("error", reply => {
      if (this._gameId == null) {
        setTimeout(() => {
          this._joinGameWithRetry(gameId, remaining - 1);
        }, 100);
      }
    });
  }


  _finishJoin(gameId) {
    let game = this._gameInfo[gameId];
    $('#game-name-span').text(game.n || "(untitled game)");
    $('#game-node-span').text(game.d);

    $('#tanx-game-list').hide();
    $('#tanx-game-info').show();

    this._gameId = gameId;
    this._joinCallbacks.forEach(callback => {
      callback(gameId, this._gameChannel);
    });
  }


  _finishRejoin() {
    this._rejoinCallbacks.forEach(callback => {
      callback(this._gameId, this._gameChannel);
    });
  }


  _leave() {
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
    gameChannel.leave();
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
