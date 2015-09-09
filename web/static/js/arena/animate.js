import ArenaRender from "web/static/js/arena/render"


const NUM_TIMESTAMPS = 10;


class ArenaAnimate {

  constructor(gameChannel, arenaSound) {
    this._gameChannel = gameChannel;
    this._arenaSound = arenaSound;
    this._arenaRender = null;
    this._receivedArena = null;
    this._receivedFrame = false;

    this._gameChannel.on("view_arena", arena => {
      if (this._arenaRender != null) {
        if (this._receivedFrame) {
          this._updateArena(arena);
        } else {
          this._receivedArena = arena;
        }
      }
    });
  }


  start(arenaStructure) {
    this._arenaRender = new ArenaRender(arenaStructure);
    this._timestamps = [];
    this._runAnimation();
  }


  stop() {
    this._arenaRender = null;
  }


  _runAnimation() {
    this._receivedArena = null;
    this._receivedFrame = false;

    this._gameChannel.push("view_arena", {});

    window.requestAnimationFrame(ignore => {
      if (this._arenaRender != null) {
        if (this._receivedArena) {
          this._updateArena(this._receivedArena);
        } else {
          this._receivedFrame = true;
        }
      }
    })
  }


  _updateArena(arena) {
    // Render the frame
    if (this._arenaRender != null) {
      this._arenaRender.render(arena);
      this._arenaSound.play(arena);
    }

    $('#tanx-arena-json').text(JSON.stringify(arena, null, 4));

    // Update FPS indicator
    if (this._timestamps.push(Date.now()) > NUM_TIMESTAMPS) {
      this._timestamps.shift();
    }
    let len = this._timestamps.length - 1
    if (len > 0) {
      let fps = Math.round(1000 * len / (this._timestamps[len] - this._timestamps[0]));
      $('#tanx-fps').text(fps);
    }

    // Request next frame
    this._runAnimation();
  }

}


export default ArenaAnimate;
