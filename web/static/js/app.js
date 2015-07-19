import {Socket} from "phoenix"

class TanxApp {

  constructor() {
    this.socket = new Socket("/ws");
    this.socket.connect()
    this.channel = this.socket.chan("game", {});

    this.hasPlayer = false;
    this.timestamps = null;
    this.numTimestamps = 10;

    this.channel.on("view_players", players => {
      this.updatePlayers(players.players);
    });
    this.channel.on("view_arena", arena => {
      if (this.hasPlayer) {
        this.updateArena(arena);
        this.channel.push("view_arena", {});
      }
    });

    this.channel.join().receive("ok", chan => {
      this.channel.push("view_players", {});
    });

    this.leavePlayer();

    $('#tanx-join-btn').on('click', () => {
      this.joinPlayer($('#tanx-name-field').val());
    });
    $('#tanx-leave-btn').on('click', () => {
      this.leavePlayer();
    });
    $('#tanx-rename-btn').on('click', () => {
      this.renamePlayer($('#tanx-name-field').val());
    });
  }


  leavePlayer() {
    $('#tanx-join-btn').show();
    $('#tanx-rename-btn').hide();
    $('#tanx-leave-btn').hide();
    $('#tanx-arena').hide();
    $('#tanx-frame-rate').hide();

    if (this.hasPlayer) {
      this.hasPlayer = false;
      this.channel.push("leave", {})
    }

  }


  joinPlayer(name) {
    $('#tanx-join-btn').hide();
    $('#tanx-rename-btn').show();
    $('#tanx-leave-btn').show();
    $('#tanx-arena').show();
    $('#tanx-frame-rate').show();

    if (!this.hasPlayer) {
      this.hasPlayer = true;
      this.timestamps = [];
      this.channel.push("join", {name: name})
    }
  }


  renamePlayer(name) {
    if (!this.hasPlayer) return;

    this.channel.push("rename", {name: name})
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
