import {Socket} from "phoenix"

class TanxApp {

  constructor() {
    this.socket = new Socket("/ws");
    this.socket.connect()
    this.channel = this.socket.chan("game", {});

    this.hasPlayer = false;
    this.hasTank = false;
    this.timestamps = null;
    this.numTimestamps = 10;

    this.upKey = false;
    this.leftKey = false;
    this.rightKey = false;

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
    $('#tanx-launch-tank-btn').on('click', () => {
      this.launchTank();
    });
    $('#tanx-remove-tank-btn').on('click', () => {
      this.removeTank();
    });

    $('#tanx-name-field').on('keypress', (event) => {
      if (event.which == 13) {
        $('#tanx-rename-btn:visible').click();
        $('#tanx-join-btn:visible').click();
      }
    });
    $('#tanx-arena').on('keydown', (event) => {
      this.keyEvent(event.which, true);
    });
    $('#tanx-arena').on('keyup', (event) => {
      this.keyEvent(event.which, false);
    });
  }


  leavePlayer() {
    $('#tanx-join-btn').show();
    $('#tanx-rename-btn').hide();
    $('#tanx-leave-btn').hide();
    $('#tanx-arena-container').hide();

    if (this.hasPlayer) {
      this.hasPlayer = false;
      this.hasTank = false;
      this.channel.push("leave", {})
    }

  }


  joinPlayer(name) {
    $('#tanx-join-btn').hide();
    $('#tanx-rename-btn').show();
    $('#tanx-leave-btn').show();
    $('#tanx-arena-container').show();

    if (!this.hasPlayer) {
      this.hasPlayer = true;
      this.timestamps = [];
      this.channel.push("join", {name: name});
    }
  }


  renamePlayer(name) {
    if (this.hasPlayer) {
      this.channel.push("rename", {name: name});
    }
  }


  launchTank() {
    if (this.hasPlayer) {
      this.channel.push("launch_tank", {});
      $('#tanx-arena').focus();
    }
  }


  removeTank() {
    if (this.hasPlayer) {
      this.channel.push("remove_tank", {});
    }
  }


  keyEvent(which, isDown) {
    console.log("Key " + which + " " + (isDown ? "down" : "up"));
    switch (which) {
      case 37:
        if (this.leftKey != isDown) {
          this.leftKey = isDown;
          this.channel.push("control_tank", {button: "left", down: isDown})
        }
        break;
      case 39:
        if (this.rightKey != isDown) {
          this.rightKey = isDown;
          this.channel.push("control_tank", {button: "right", down: isDown})
        }
        break;
      case 38:
        if (this.upKey != isDown) {
          this.upKey = isDown;
          this.channel.push("control_tank", {button: "forward", down: isDown})
        }
        break;
    }
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
    $('#tanx-arena-text').text(JSON.stringify(arena, null, 4));
    let hasTank = arena.tanks.some(tank => tank.is_me);
    $('#tanx-launch-tank-btn').toggle(!hasTank);
    $('#tanx-remove-tank-btn').toggle(hasTank);
  }

}


let App = new TanxApp();
window.Tanx = App;

export default App;
