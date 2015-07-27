import {Socket} from "phoenix"

class TanxApp {

  // TODO: Break this up into multiple classes.

  constructor() {
    // Configuration
    this.NUM_TIMESTAMPS = 10;
    this.MAX_CANVAS_WIDTH = 600;
    this.MAX_CANVAS_HEIGHT = 600;

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

    $('#tanx-name-field')
      .on('keyup', (event) => {
        if (this._hasPlayer) {
          this.renamePlayer();
        } else {
          if (event.which == 13) {
            this.joinPlayer();
          }
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

    $('#tanx-canvas').on('keydown', (event) => {
      this.arenaKeyEvent(event, true);
    });
    $('#tanx-canvas').on('keyup', (event) => {
      this.arenaKeyEvent(event, false);
    });

    $('#tanx-launch-tank-btn').on('click', () => {
      this.launchTank();
    });
    $('#tanx-remove-tank-btn').on('click', () => {
      this.removeTank();
    });
  }


  arenaKeyEvent(event, isDown) {
    switch (event.which) {
      case 37: // left arrow
      case 74: // J
        if (this._leftKey != isDown) {
          this._leftKey = isDown;
          this.pushToChannel("control_tank", {button: "left", down: isDown})
        }
        event.preventDefault();
        break;
      case 32: // space
        if (this._spaceKey != isDown) {
          this._spaceKey = isDown;
          this.pushToChannel("fire_missile", {button: "space", down: isDown})
        }
        event.preventDefault();
        break;
      case 39: // right arrow
      case 76: // L
        if (this._rightKey != isDown) {
          this._rightKey = isDown;
          this.pushToChannel("control_tank", {button: "right", down: isDown})
        }
        event.preventDefault();
        break;
      case 38: // up arrow
      case 40: // down arrow
      case 73: // I
      case 75: // K
        if (this._upKey != isDown) {
          this._upKey = isDown;
          this.pushToChannel("control_tank", {button: "forward", down: isDown})
        }
        event.preventDefault();
        break;
    }
  }


  launchTank() {
    if (this.hasPlayer()) {
      this.pushToChannel("launch_tank", {});
      $('#tanx-canvas').focus();
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
    this._timestamps = null;
    this._receivedArena = null;
    this._receivedFrame = false;
    this._structure = null;
    this._scaleFactor = null;

    this.onChannelEvent("view_arena", arena => {
      if (this.hasPlayer()) {
        if (this._receivedFrame) {
          this.updateArena(arena);
        } else {
          this._receivedArena = arena;
        }
      }
    });

    this.onChannelEvent("view_structure", structure => {
      this._structure = structure;
      let xScale = this.MAX_CANVAS_WIDTH / structure.width;
      let yScale = this.MAX_CANVAS_HEIGHT / structure.height;
      this._scaleFactor = xScale < yScale ? xScale : yScale;
      $('#tanx-canvas').attr({
        width: this._scaleFactor * structure.width,
        height: this._scaleFactor * structure.height
      });
    });
  }


  startArenaAnimation() {
    this._structure = null;
    this._timestamps = [];
    this.pushToChannel("view_structure");
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
    $('#tanx-arena-json').text(JSON.stringify(arena, null, 4));

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
    if(this.canvas() && this._structure) {
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

      // Draw explosions
      arena.explosions.forEach(explosion => {
        this.renderExplosion(context, explosion);
      });

      // Draw maze walls
      this._structure.walls.forEach(wall => {
        this.renderWall(context, wall);
      });
    }
  }


  renderWall(context, wall) {
    context.save();
    context.strokeStyle = '#934b36';
    context.beginPath();
    let point = this.onScreenPoint(wall[0], wall[1]);
    context.moveTo(point.x, point.y);
    for (let i=2; i<wall.length; i += 2) {
      point = this.onScreenPoint(wall[i], wall[i+1]);
      context.lineTo(point.x, point.y);
      context.lineWidth = 3;
    }
    context.closePath();
    context.stroke();
    context.restore();
  }


  renderTank(context, tank) {
    context.save();

    let tankRect = this.onScreenRect(tank.x, tank.y, tank.radius*2, tank.radius*2);
    context.translate(tankRect.x, tankRect.y);

    // Add names above enemies
    if(tank.is_me === false) {
      context.textAlign = "center";
      context.fillText(tank.name, 0, -15);
    }

    let tankImage = new Image();
    tankImage.src = 'images/tank_sprite.png';

    let rotateTankImage90Degrees = 90 * Math.PI/180;
    context.rotate(-tank.heading + rotateTankImage90Degrees);

    let spriteSheetX = 92;
    let spriteSheetY = tank.is_me ? 1 : 84;
    let screenRadius = Math.ceil(this._scaleFactor * 0.5);
    context.drawImage(tankImage, spriteSheetX, spriteSheetY, 67, 79,
        -screenRadius, -screenRadius, screenRadius * 2, screenRadius * 2);

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


  renderExplosion(context, explosion) {
    context.save();

    let point = this.onScreenPoint(explosion.x, explosion.y);
    let radius = explosion.radius * this._scaleFactor;
    if (explosion.age < 0.5) {
      radius = radius * explosion.age * 2.0;
    }
    context.beginPath();
    context.fillStyle = "#fa4";
    context.arc(point.x, point.y, radius, 0, Math.PI*2, false);
    context.fill();
    if (explosion.age > 0.5) {
      radius = explosion.radius * this._scaleFactor * (explosion.age - 0.5) * 2.0;
      context.beginPath();
      context.fillStyle = "#fff";
      context.arc(point.x, point.y, radius, 0, Math.PI*2, false);
      context.fill();
    }

    context.restore();
  }


  canvas() {
    return $('#tanx-canvas').get(0);
  }


  onScreenPoint(x, y) {
    let xOffset = this.canvas().width / 2;
    let yOffset = this.canvas().height / 2;

    let screenX = xOffset + (x * this._scaleFactor);
    let screenY = yOffset - (y * this._scaleFactor);
    return {x: screenX, y: screenY};
  }


  onScreenRect(x, y, width, height) {
    let screenPoint = this.onScreenPoint(x, y);
    let screenWidth = width * this._scaleFactor;
    let screenHeight = height * this._scaleFactor;
    return {x: screenPoint.x, y: screenPoint.y, width: screenWidth, height: screenHeight};
  }


}


let App = new TanxApp();
window.Tanx = App;

export default App;
