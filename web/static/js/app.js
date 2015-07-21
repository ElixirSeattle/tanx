import {Socket} from "phoenix"

class TanxApp {

  // TODO: Break this up into multiple classes.

  constructor() {
    this.setupChannel();
    this.setupPlayerList();
    this.setupPlayerControl();
    this.setupArenaControls();
    this.setupArenaAnimation();
  }


  //////////////////////////////////////////////////////////////////////////////
  // CHANNEL CONTROL


  setupChannel() {
    let socket = new Socket("/ws");
    socket.connect()
    this._channel = socket.chan("game", {});

    this._channel.join().receive("ok", chan => {
      this.setupPlayerList();
    });
  }


  pushToChannel(event, payload) {
    if (!payload) payload = {};
    this._channel.push(event, payload);
  }


  onChannelEvent(event, callback) {
    this._channel.on(event, callback);
  }


  //////////////////////////////////////////////////////////////////////////////
  // PLAYER LIST VIEW


  setupPlayerList() {
    // Make sure we get an initial view. Subsequent changes will be broadcasted
    // from the server.
    this.pushToChannel("view_players");

    this.onChannelEvent("view_players", players => {
      this.renderPlayersTable(players.players);
    });
  }


  renderPlayersTable(players) {
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


  //////////////////////////////////////////////////////////////////////////////
  // PLAYER JOINING AND RENAMING CONTROL


  setupPlayerControl() {
    this._hasPlayer = false;

    $('#tanx-join-btn').on('click', () => {
      this.joinPlayer();
    });
    $('#tanx-leave-btn').on('click', () => {
      this.leavePlayer();
    });
    $('#tanx-rename-btn').on('click', () => {
      this.renamePlayer();
    });

    $('#tanx-name-field').on('keypress', (event) => {
      if (event.which == 13) {
        $('#tanx-rename-btn:visible').click();
        $('#tanx-join-btn:visible').click();
      }
    });

    this.leavePlayer();
  }


  joinPlayer() {
    $('#tanx-join-btn').hide();
    $('#tanx-rename-btn').show();
    $('#tanx-leave-btn').show();
    $('#tanx-arena-container').show();

    if (!this._hasPlayer) {
      this._hasPlayer = true;
      this.pushToChannel("join", {name: $('#tanx-name-field').val()});
      this.startArenaAnimation();
    }
  }


  leavePlayer() {
    $('#tanx-join-btn').show();
    $('#tanx-rename-btn').hide();
    $('#tanx-leave-btn').hide();
    $('#tanx-arena-container').hide();

    if (this._hasPlayer) {
      this._hasPlayer = false;
      this.pushToChannel("leave");
    }
  }


  renamePlayer() {
    if (this.hasPlayer()) {
      this.pushToChannel("rename", {name: $('#tanx-name-field').val()});
    }
  }


  hasPlayer() {
    return this._hasPlayer;
  }


  //////////////////////////////////////////////////////////////////////////////
  // ARENA CONTROLS


  setupArenaControls() {
    this._upKey = false;
    this._leftKey = false;
    this._rightKey = false;

    $('#tanx-arena').on('keydown', (event) => {
      this.arenaKeyEvent(event.which, true);
    });
    $('#tanx-arena').on('keyup', (event) => {
      this.arenaKeyEvent(event.which, false);
    });

    $('#tanx-launch-tank-btn').on('click', () => {
      this.launchTank();
    });
    $('#tanx-remove-tank-btn').on('click', () => {
      this.removeTank();
    });
  }


  arenaKeyEvent(which, isDown) {
    switch (which) {
      case 37: // left arrow
      case 74: // J
        if (this._leftKey != isDown) {
          this._leftKey = isDown;
          this.pushToChannel("control_tank", {button: "left", down: isDown})
        }
        break;
      case 32: // space
        if (this._spaceKey != isDown) {
          this._spaceKey = isDown;
          this.pushToChannel("fire_missile", {button: "space", down: isDown})
        }
        break;
      case 39: // right arrow
      case 76: // L
        if (this._rightKey != isDown) {
          this._rightKey = isDown;
          this.pushToChannel("control_tank", {button: "right", down: isDown})
        }
        break;
      case 38: // up arrow
      case 40: // down arrow
      case 73: // I
      case 75: // K
        if (this._upKey != isDown) {
          this._upKey = isDown;
          this.pushToChannel("control_tank", {button: "forward", down: isDown})
        }
        break;
    }
  }


  launchTank() {
    if (this.hasPlayer()) {
      this.pushToChannel("launch_tank", {});
      $('#tanx-arena').focus();
    }
  }


  removeTank() {
    if (this.hasPlayer()) {
      this.pushToChannel("remove_tank", {});
    }
  }


  //////////////////////////////////////////////////////////////////////////////
  // ARENA ANIMATION


  setupArenaAnimation() {
    this.NUM_TIMESTAMPS = 10;
    this._timestamps = null;
    this._receivedArena = null;
    this._receivedFrame = false;

    this.onChannelEvent("view_arena", arena => {
      if (this.hasPlayer()) {
        if (this._receivedFrame) {
          this.updateArena(arena);
        } else {
          this._receivedArena = arena;
        }
      }
    });
  }


  startArenaAnimation() {
    this._timestamps = [];
    this.runAnimation();
  }


  runAnimation() {
    this._receivedArena = null;
    this._receivedFrame = false;

    this.pushToChannel("view_arena");

    window.requestAnimationFrame(ignore => {
      if (this.hasPlayer()) {
        if (this._receivedArena) {
          this.updateArena(this._receivedArena);
        } else {
          this._receivedFrame = true;
        }
      }
    })
  }


  updateArena(arena) {
    // Render the frame
    this.renderArena(arena);

    // Update FPS indicator
    if (this._timestamps.push(Date.now()) > this.NUM_TIMESTAMPS) {
      this._timestamps.shift();
    }
    let len = this._timestamps.length - 1
    if (len > 0) {
      let fps = Math.round(1000 * len / (this._timestamps[len] - this._timestamps[0]));
      $('#tanx-fps').text(fps);
    }

    // Update tank launch/remove buttons
    let hasTank = arena.tanks.some(tank => tank.is_me);
    $('#tanx-launch-tank-btn').toggle(!hasTank);
    $('#tanx-remove-tank-btn').toggle(hasTank);

    // Request next frame
    this.runAnimation();
  }

  renderArena(arena) {
    $('#tanx-arena pre').text(JSON.stringify(arena, null, 4));

    if(this.canvas()) {
      var context = this.canvas().getContext("2d");

      // Clear the canvas
      context.clearRect(0, 0, this.canvas().width, this.canvas().height);

      // Draw tanks
      arena.tanks.forEach(tank => {
        this.renderTank(context, tank);
      });

      // Draw missiles
      arena.missiles.forEach(missile => {
        this.renderMissile(context, missile);
      });
    }
  }

  renderTank(context, tank) {
    context.save();

    let tankRect = this.onScreenRect(tank.x, tank.y, tank.radius*2, tank.radius*2);
    let barrelRect = this.onScreenRect(tank.x, tank.y, 1, 0.2);

    context.translate(tankRect.x, tankRect.y);

    if(tank.is_me) {
      // my tank color
      context.fillStyle = "#0000FF";
    } else {
      // Add names above enemies
      context.textAlign = "center";
      context.fillText(tank.name, 0, -11);

      // enemy tank color
      context.fillStyle = "#FF0000";
    }

    context.rotate(-tank.heading);

    // TODO: Replace this with some nice graphics
    context.fillRect(-tankRect.width/2, -tankRect.height/2, tankRect.width, tankRect.height);
    context.fillRect(0, -barrelRect.height/2, barrelRect.width, barrelRect.height)

    context.restore();
  }

  renderMissile(context, missile) {
    context.save();

    let missileRect = this.onScreenRect(missile.x, missile.y, 0.2, 0.2);
    context.translate(missileRect.x, missileRect.y);

    context.rotate(-missile.heading);

    // TODO: Replace this with some nice graphics
    context.fillStyle = "#00FF00";
    context.fillRect(-missileRect.width/2, -missileRect.height/2, missileRect.width, missileRect.height);

    context.restore();
  }

  canvas() {
    return $('#tanx-arena canvas').get(0);
  }

  onScreenPoint(x, y) {
    let offset = this.canvas().width / 2;
    let scaleFactor = 10; // TODO: This should be calculated with: offset / arena.radius

    let screenX = offset + (x * scaleFactor);
    let screenY = offset - (y * scaleFactor);
    return {x: screenX, y: screenY};
  }

  onScreenRect(x, y, width, height) {
    let scaleFactor = 10; // TODO: This should be calculated with: offset / arena.radius

    let screenPoint = this.onScreenPoint(x, y);
    let screenWidth = width * scaleFactor;
    let screenHeight = height * scaleFactor;
    return {x: screenPoint.x, y: screenPoint.y, width: screenWidth, height: screenHeight};
  }


}


let App = new TanxApp();
window.Tanx = App;

export default App;
