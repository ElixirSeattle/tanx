import {Socket} from "phoenix"

class TanxApp {

  constructor() {
    this.socket = new Socket("/ws");
    this.socket.connect()
    this.lobbyChan = null;
    this.playerChan = null;
    this.timestamps = null;
    this.numTimestamps = 10;

    this.joinLobby();

    $('#tanx-join-btn').on('click', () => {
      this.joinPlayer($('#tanx-name-field').val());
    });
    $('#tanx-leave-btn').on('click', () => {
      this.joinLobby();
    });
    $('#tanx-rename-btn').on('click', () => {
      this.renamePlayer($('#tanx-name-field').val());
    });
  }


  joinLobby() {
    if (this.lobbyChan) return;

    if (this.playerChan) {
      this.playerChan.leave();
      this.playerChan = null;
    }
    this.lobbyChan = this.socket.chan("lobby", {});
    this.lobbyChan.on("view_players", players => {
      if (this.lobbyChan) {
        this.updatePlayers(players.players);
      }
    });
    this.lobbyChan.join().receive("ok", chan => {
      this.lobbyChan.push("view_players", {});
    });

    $('#tanx-join-btn').show();
    $('#tanx-rename-btn').hide();
    $('#tanx-leave-btn').hide();
    $('#tanx-arena').hide();
    $('#tanx-frame-rate').hide();
  }


  joinPlayer(name) {
    if (this.playerChan) return;

    if (this.lobbyChan) {
      this.lobbyChan.leave();
      this.lobbyChan = null;
    }
    this.playerChan = this.socket.chan("player", {name: name});
    this.timestamps = [];
    this.playerChan.on("view_players", players => {
      if (this.playerChan) {
        this.updatePlayers(players.players);
      }
    });
    this.playerChan.on("view_arena", arena => {
      if (this.playerChan) {
        this.updateArena(arena);
        this.playerChan.push("view_arena", {});
      }
    });
    this.playerChan.join().receive('ok', chan => {
      this.playerChan.push("view_players", {});
      this.playerChan.push("view_arena", {});
    });

    $('#tanx-join-btn').hide();
    $('#tanx-rename-btn').show();
    $('#tanx-leave-btn').show();
    $('#tanx-arena').show();
    $('#tanx-frame-rate').show();
  }


  renamePlayer(name) {
    if (!this.playerChan) return;

    this.playerChan.push("rename", {name: name})
  }


  updatePlayers(players) {
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


  updateArena(arena) {
    if (this.timestamps.push(Date.now()) > this.numTimestamps) {
      this.timestamps.shift();
    }
    let len = this.timestamps.length - 1
    if (len > 0) {
      let fps = Math.round(1000 * len / (this.timestamps[len] - this.timestamps[0]));
      $('#tanx-fps').text(fps);
    }
    $('#tanx-arena').text(JSON.stringify(arena));
  }

}


let App = new TanxApp();
window.Tanx = App;

export default App;
