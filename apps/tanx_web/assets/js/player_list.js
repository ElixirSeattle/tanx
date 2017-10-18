
class PlayerList {

  constructor(gameChannel, chatClient) {
    this._hasPlayer = false;
    this._gameChannel = gameChannel;
    this._chatClient = chatClient;
    this._joinCallbacks = [];
    this._leaveCallbacks = [];

    this._joinGameChannel();
    this._setupControls();
  }


  onJoin(callback) {
    this._joinCallbacks.push(callback);
  }


  onLeave(callback) {
    this._leaveCallbacks.push(callback);
  }


  _joinGameChannel() {
    this._gameChannel.join().receive("ok", chan => {
      // Make sure we get an initial view. Subsequent changes will be broadcasted
      // from the server.
      this._gameChannel.push("view_players", {});

      this._gameChannel.on("view_players", players => {
        this._renderPlayersTable(players.players);
      });
    });
  }


  _setupControls() {
    $('#tanx-join-btn').on('click', () => {
      this._joinPlayer();
    });
    $('#tanx-leave-btn').on('click', () => {
      this._leavePlayer();
    });

    $('#tanx-name-field')
      .on('keyup', (event) => {
        if (this._hasPlayer) {
          this._renamePlayer();
        } else {
          if (event.which == 13) {
            this._joinPlayer();
          }
        }
        event.stopPropagation();
      })
      .on('keydown', (event) => {
        event.stopPropagation();
      });

    this._leavePlayer();
  }


  _renderPlayersTable(players) {
    let playerTable = $('#player-rows');
    playerTable.empty();
    if (players.length == 0) {
      playerTable.html('<tr><td colspan="3">(No players)</td></tr>');
    } else {
      players.forEach(player => {
        let row = $('<tr>');
        if (player.is_me) {
          row.addClass('info');
        }
        row.html('<td>' + player.name + '</td><td>' + player.kills +
          '</td><td>' + player.deaths + '</td>');
        playerTable.append(row);
      });
    }
  }


  _joinPlayer() {
    $('#tanx-join-btn').hide();
    $('#tanx-rename-btn').show();
    $('#tanx-leave-btn').show();
    $('#tanx-arena-container').show();
    $('#tanx-chat').show()

    if (!this._hasPlayer) {
      this._hasPlayer = true;
      this._gameChannel.push("join", {name: this._escapedTankName()});
      this._chatClient.push("join", {name: this._escapedTankName()});
      this._joinCallbacks.forEach(callback => {
        callback();
      });
    }
  }


  _leavePlayer() {
    $('#tanx-join-btn').show();
    $('#tanx-rename-btn').hide();
    $('#tanx-leave-btn').hide();
    $('#tanx-arena-container').hide();
    $('#tanx-chat').hide()

    let backgroundMusic = $('#background-music')[0];
    backgroundMusic.pause();
    if (backgroundMusic.currentTime) {
      backgroundMusic.currentTime = "0";
    }

    if (this._hasPlayer) {
      this._hasPlayer = false;
      this._gameChannel.push("leave", {});
      this._chatClient.push("leave", {name: this._escapedTankName()});
      this._leaveCallbacks.forEach(callback => {
        callback();
      });
    }
  }


  _renamePlayer() {
    if (this._hasPlayer) {
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


export default PlayerList;
