
class Lobby {

  constructor(socket) {
    this._socket = socket;
    this._gameId = null;
    this._gameChannel = null;
    this._chatChannel = null;
    this._joinCallbacks = [];
    this._leaveCallbacks = [];

    this._setupControls();

    this._setupGameList();
  }


  onJoin(callback) {
    this._joinCallbacks.push(callback);
  }


  onLeave(callback) {
    this._leaveCallbacks.push(callback);
  }


  _setupControls() {
    $('#tanx-leave-btn').on('click', () => {
      this._leave();
    });

    $('#tanx-name-field')
      .on('keyup', (event) => {
        this._renamePlayer();
        event.stopPropagation();
      })
      .on('keydown', (event) => {
        event.stopPropagation();
      });

    this._leave();
  }


  _setupGameList() {
    this._lobbyChannel = this._socket.channel("lobby", {});
    this._lobbyChannel.join();
    this._lobbyChannel.on("update", update => {
      this._updateGameTable(update.g)
    });
  }


  _updateGameTable(games) {
    let gameTable = $('#game-rows');
    gameTable.empty();
    if (games.length == 0) {
      gameTable.html('<tr><td colspan="3">(No games)</td></tr>');
    } else {
      games.forEach(game => {
        let row = $('<tr>');
        let name = game.n || "(Untitled game)";
        row.html('<td>' +
          '<button class="btn btn-default btn-sm tanx-join-btn" data-game-id="' +
            game.i + '">Join</button>' +
          '<button class="btn btn-default btn-sm tanx-delete-btn" data-game-id="' +
            game.i + '">Delete</button>' +
          '<span style="padding-left: 10px;">' + name + '</span></td>');
        gameTable.append(row);
      });
      $('.tanx-join-btn').on('click', (event) => {
        this._join($(event.target).attr("data-game-id"));
      });
    }
  }


  _join(gameId) {
    if (this._gameId != null) return;

    let playerName = this._escapedTankName();
    let gameChannel = this._socket.channel("game:" + gameId, {name: playerName});
    let chatChannel = this._socket.channel("chat:" + gameId, {});

    gameChannel.join().receive("ok", chan => {
      chatChannel.join().receive("ok", cchan => {
        if (this._gameId != null) return;

        $('#tanx-game-list').hide();
        $('#tanx-leave-btn').show();
        $('#tanx-arena-container').show();
        $('#tanx-chat').show();

        this._gameId = gameId;
        this._gameChannel = gameChannel;
        this._chatChannel = chatChannel;
        this._joinCallbacks.forEach(callback => {
          callback(gameId, gameChannel, chatChannel);
        });
      });
    });
  }


  _leave() {
    $('#tanx-game-list').show();
    $('#tanx-leave-btn').hide();
    $('#tanx-arena-container').hide();
    $('#tanx-chat').hide();

    let backgroundMusic = $('#background-music')[0];
    backgroundMusic.pause();
    if (backgroundMusic.currentTime) {
      backgroundMusic.currentTime = "0";
    }

    if (this._gameId == null) return;

    let gameId = this._gameId;
    let gameChannel = this._gameChannel;
    let chatChannel = this._chatChannel;
    this._gameChannel = null;
    this._chatChannel = null;
    this._gameId = null;
    this._leaveCallbacks.forEach(callback => {
      callback(gameId, gameChannel, chatChannel);
    });
    gameChannel.leave();
  }


  _renamePlayer() {
    if (this._gameId != null) {
      this._gameChannel.push("rename", {name: this._escapedTankName()});
    }
  }

  _escapedTankName(){
    return this._escapeHtml($('#tanx-name-field').val())
  }

  _escapeHtml(str) {
    var div = document.createElement('div');
    div.appendChild(document.createTextNode(str));
    return div.innerHTML
  }

}


export default Lobby;
