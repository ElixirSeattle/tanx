import {Socket} from "deps/phoenix/web/static/js/phoenix"
import "deps/phoenix_html/web/static/js/phoenix_html"

class TanxApp {

  // TODO: Break this up into multiple classes.

  constructor() {
    // Configuration
    this.NUM_TIMESTAMPS = 10;
    this.MAX_CANVAS_WIDTH = 600;
    this.MAX_CANVAS_HEIGHT = 600;
    this.BACKGROUND_MUSIC = new Audio("sounds/tanx-music-loop.m4a");
    this.BACKGROUND_MUSIC.volume = .4;
    this.HEARTBEAT_MILLIS = 60000;

    this.setupChannels();
    this.setupPlayerList();
    this.setupPlayerControl();
    this.setupArenaControls();
    this.setupArenaAnimation();
  }


  //////////////////////////////////////////////////////////////////////////////
  // CHANNEL CONTROL


  setupChannels() {
    this._heartbeatTimeout = null;

    let socket = new Socket("/ws");
    socket.connect()

    this.setupGameChannel(socket);
    this.setupChatChannel(socket);

    this.scheduleHeartbeat();
  }

  setupGameChannel(socket) {
    this._game_channel = socket.channel("game", {});

    this._game_channel.join().receive("ok", chan => {
      this.setupPlayerList();
    });
  }

  setupChatChannel(socket) {
    this._chat_channel = socket.channel("chat", {});
    this._chat_channel.join().receive("ok", () => {
      let channel = this._chat_channel;
      let that = this;

      channel.on("user:entered", function(message){
        $("#messages").append("<p class='row message'><span class='user-entered'>"+that.sanitize(message.username)+" entered</span></p>")
      });

      channel.on("user:left", function(message){
        $("#messages").append("<p class='row message'><span class='user-left'>"+that.sanitize(message.username) +" left</span></p>")
      });

      channel.on("new:message", function(msg){
        $("#messages").append("<p class='row message'><span class='username'>"+that.sanitize(msg.username)+"</span><span class='content'>"+that.sanitize(msg.content)+"</span></p>");
        $('#messages').scrollTop($('#messages')[0].scrollHeight);
      });

      $("#message-input").off("keypress").on("keypress", function(e){
        if(e.keyCode == 13){
          channel.push("new:message", {
            content: $("#message-input").val(),
            username: $("#tanx-name-field").val()
          });
          $("#message-input").val("");
        }
      });
    });
  }

  sanitize(html){ return $("<span/>").text(html).html() }

  pushToChannel(channel, event, payload) {
    if (!payload) payload = {};
    channel.push(event, payload);

    if (this._heartbeatTimeout) {
      clearTimeout(this._heartbeatTimeout);
      this._heartbeatTimeout = null;
    }
    this.scheduleHeartbeat();
  }


  scheduleHeartbeat() {
    this._heartbeatTimeout = setTimeout(() => {
      this._heartbeatTimeout = null;
      this.pushToChannel(this._game_channel, 'heartbeat', null);
    }, this.HEARTBEAT_MILLIS);
  }

  onChannelEvent(channel, event, callback) {
    channel.on(event, callback);
  }

  //////////////////////////////////////////////////////////////////////////////
  // PLAYER LIST VIEW


  setupPlayerList() {
    // Make sure we get an initial view. Subsequent changes will be broadcasted
    // from the server.
    this.pushToChannel(this._game_channel, "view_players");

    this.onChannelEvent(this._game_channel, "view_players", players => {
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
    $('#tanx-chat').show()

    if (!this._hasPlayer) {
      this._hasPlayer = true;
      this.pushToChannel(this._game_channel, "join", {name: $('#tanx-name-field').val()});
      this.pushToChannel(this._chat_channel, "join", {name: $('#tanx-name-field').val()});
      this.startArenaAnimation();
    }
  }


  leavePlayer() {
    $('#tanx-join-btn').show();
    $('#tanx-rename-btn').hide();
    $('#tanx-leave-btn').hide();
    $('#tanx-arena-container').hide();
    $('#tanx-chat').hide()

    this.BACKGROUND_MUSIC.pause();
    //This breaks on Firefox and Safari. Need to find a way to reset background music that has better browser support.
    //this.BACKGROUND_MUSIC.currentTime = 0;

    if (this._hasPlayer) {
      this._hasPlayer = false;
      this.pushToChannel(this._game_channel, "leave");
      this.pushToChannel(this._chat_channel, "leave", {name: $('#tanx-name-field').val()});
    }
  }


  renamePlayer() {
    if (this.hasPlayer()) {
      this.pushToChannel(this._game_channel, "rename", {name: $('#tanx-name-field').val()});
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

    $('#tanx-canvas').on('click', (event) => {
      let offset = $('#tanx-canvas').offset();
      this.handleArenaClick(event.pageX - offset.left, event.pageY - offset.top);
    });
  }


  arenaKeyEvent(event, isDown) {
    if (!this.hasPlayer()) {
      return;
    }
    switch (event.which) {
      case 37: // left arrow
      case 74: // J
        if (this._leftKey != isDown) {
          this._leftKey = isDown;
          this.pushToChannel(this._game_channel, "control_tank", {button: "left", down: isDown})
        }
        event.preventDefault();
        break;
      case 32: // space
        if (this._spaceKey != isDown) {
          this._spaceKey = isDown;
          this.pushToChannel(this._game_channel, "fire_missile", {button: "space", down: isDown})
        }
        event.preventDefault();
        break;
      case 39: // right arrow
      case 76: // L
        if (this._rightKey != isDown) {
          this._rightKey = isDown;
          this.pushToChannel(this._game_channel, "control_tank", {button: "right", down: isDown})
        }
        event.preventDefault();
        break;
      case 38: // up arrow
      case 40: // down arrow
      case 73: // I
      case 75: // K
        if (this._upKey != isDown) {
          this._upKey = isDown;
          this.pushToChannel(this._game_channel, "control_tank", {button: "forward", down: isDown})
        }
        event.preventDefault();
        break;
      case 68: // D
      case 90: // Z
        if (isDown) {
          this.pushToChannel(this._game_channel, "self_destruct_tank", {});
        }
        event.preventDefault();
        break;
    }
  }


  handleArenaClick(x, y) {
    if (this._structure && this.hasPlayer()) {
      let dist = this._structure.entry_point_radius * this._scaleFactor;
      let distSquared = dist * dist;
      this._structure.entry_points.forEach(ep => {
        let point = this.onScreenPoint(ep.x, ep.y);
        if ((x - point.x) * (x - point.x) + (y - point.y) * (y - point.y) <= distSquared) {
          this.pushToChannel(this._game_channel, "launch_tank", {entry_point: ep.name});
        }
      });
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

    this.onChannelEvent(this._game_channel, "view_arena", arena => {
      if (this.hasPlayer()) {
        if (this._receivedFrame) {
          this.updateArena(arena);
        } else {
          this._receivedArena = arena;
        }
      }
    });

    this.onChannelEvent(this._game_channel, "view_structure", structure => {
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
    this.pushToChannel(this._game_channel, "view_structure");
    this.runAnimation();
  }


  runAnimation() {
    this._receivedArena = null;
    this._receivedFrame = false;

    this.pushToChannel(this._game_channel, "view_arena");

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

    // Request next frame
    this.runAnimation();
  }


  renderArena(arena) {
    if(this.canvas() && this._structure) {
      let hasTank = arena.tanks.some(tank => tank.is_me);

      var context = this.canvas().getContext("2d");

      // Clear the canvas
      context.clearRect(0, 0, this.canvas().width, this.canvas().height);

      // Draw maze walls
      this._structure.walls.forEach(wall => {
        this.renderWall(context, wall);
      });

      // Draw entry points
      this._structure.entry_points.forEach(ep => {
        this.renderEntryPoint(context, ep, arena.entry_points_available[ep.name]);
      });

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

      // Start background music
      this.BACKGROUND_MUSIC.play();
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


  renderEntryPoint(context, entryPoint, isAvailable) {
    context.save();

    let point = this.onScreenPoint(entryPoint.x, entryPoint.y);
    let radius = this._structure.entry_point_radius * this._scaleFactor;
    let time = Date.now() % 1000;
    if (time < 500) {
      radius = radius * time / 500;
    } else {
      radius = radius * (1000 - time) / 500;
    }
    context.beginPath();
    context.strokeStyle = isAvailable ? '#ff0' : '#bb8';
    context.arc(point.x, point.y, radius, 0, Math.PI*2, false);
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
      context.fillText(tank.name, 0, -this._scaleFactor * 0.7);
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
    context.fillStyle = "#000";
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

    if (explosion.age < .07) {
      var explosionSound = new Audio("sounds/Explosion3.wav");
      explosionSound.play();
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
