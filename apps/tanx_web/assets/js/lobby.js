
class Lobby {

  constructor(socket) {
    this._socket = socket;
    this._gameId = null;
    this._gameChannel = null;
    this._chatChannel = null;
    this._joinCallbacks = [];
    this._leaveCallbacks = [];

    this._setupControls();
  }


  onJoin(callback) {
    this._joinCallbacks.push(callback);
  }


  onLeave(callback) {
    this._leaveCallbacks.push(callback);
  }


  _setupControls() {
    $('#tanx-join-btn').on('click', () => {
      this._join("game1");
    });
    $('#tanx-leave-btn').on('click', () => {
      this._leave();
    });

    $('#tanx-name-field')
      .on('keyup', (event) => {
        if (this._gameId != null) {
          this._renamePlayer();
        } else {
          if (event.which == 13) {
            this._join("game1");
          }
        }
        event.stopPropagation();
      })
      .on('keydown', (event) => {
        event.stopPropagation();
      });

    this._leave();
  }


  _join(gameId) {
    if (this._gameId != null) return;

    let playerName = this._escapedTankName();
    let gameChannel = this._socket.channel("game:" + gameId, {name: playerName});
    let chatChannel = this._socket.channel("chat:" + gameId, {});

    gameChannel.join().receive("ok", chan => {
      chatChannel.join().receive("ok", cchan => {
        if (this._gameId != null) return;

        $('#tanx-join-btn').hide();
        $('#tanx-rename-btn').show();
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
    $('#tanx-join-btn').show();
    $('#tanx-rename-btn').hide();
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
