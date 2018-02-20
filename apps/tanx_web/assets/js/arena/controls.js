
class ArenaControls {

  constructor(gameChannel) {
    this._gameChannel = gameChannel;
    this._arenaStructure = null;
    this._upKey = false;
    this._downKey = false;
    this._leftKey = false;
    this._rightKey = false;

    $('body').on('keydown', (event) => {
      this._arenaKeyEvent(event, true);
    });
    $('body').on('keyup', (event) => {
      this._arenaKeyEvent(event, false);
    });

    $('#tanx-canvas').on('click', (event) => {
      let offset = $('#tanx-canvas').offset();
      this._handleArenaClick(event.pageX - offset.left, event.pageY - offset.top);
    });
  }


  start(arenaStructure) {
    this._arenaStructure = arenaStructure;
    this._upKey = false;
    this._leftKey = false;
    this._rightKey = false;
  }


  stop() {
    this._arenaStructure = null;
  }


  _arenaKeyEvent(event, isDown) {
    if (this._arenaStructure == null) {
      return;
    }
    switch (event.which) {
      case 37: // left arrow
      case 74: // J
        if (this._leftKey != isDown) {
          this._leftKey = isDown;
          this._gameChannel.push("control_tank", {button: "left", down: isDown})
        }
        event.preventDefault();
        break;
      case 32: // space
        if (this._spaceKey != isDown) {
          this._spaceKey = isDown;
          this._gameChannel.push("control_tank", {button: "fire", down: isDown})
        }
        event.preventDefault();
        break;
      case 39: // right arrow
      case 76: // L
        if (this._rightKey != isDown) {
          this._rightKey = isDown;
          this._gameChannel.push("control_tank", {button: "right", down: isDown})
        }
        event.preventDefault();
        break;
      case 38: // up arrow

      case 73: // I
      //case 75: // K
        if (this._upKey != isDown) {
          this._upKey = isDown;
          this._gameChannel.push("control_tank", {button: "forward", down: isDown})
        }
        event.preventDefault();
        break;
      case 40: // down arrow
      case 75: // K
        if (this._downKey != isDown) {
          this._downKey = isDown;
          this._gameChannel.push("control_tank", {button: "backward", down: isDown})
        }
        event.preventDefault();
        break;
      //case 68: // D
      case 90: // Z
        if (isDown) {
          this._gameChannel.push("self_destruct_tank", {});
        }
        event.preventDefault();
        break;
    }
  }


  _handleArenaClick(x, y) {
    if (this._arenaStructure != null) {
      let entryPoint = this._arenaStructure.findEntryPoint(x, y);
      if (entryPoint) {
        this._gameChannel.push("launch_tank", {entry_point: entryPoint.n});
      }
    }
  }

}


export default ArenaControls;
