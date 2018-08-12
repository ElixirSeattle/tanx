import ArenaStructure from "js/arena/structure"
import ArenaControls from "js/arena/controls"


class Arena {

  constructor(arenaAnimate) {
    $('#tanx-arena-container').hide();
    this._arenaControls = new ArenaControls();
    this._arenaAnimate = arenaAnimate;
  }


  start(gameId, gameChannel) {
    $('#tanx-arena-container').show();
    gameChannel.push("view_structure", {});
    gameChannel.on("view_structure", structure => {
      if (structure.h != null) {
        let arenaStructure = new ArenaStructure(structure);
        this._arenaControls.start(gameChannel, arenaStructure);
        this._arenaAnimate.start(gameId, gameChannel, arenaStructure);
      }
    });
  }


  restart(gameChannel) {
    this._arenaAnimate.restart(gameChannel);
  }


  stop() {
    $('#tanx-arena-container').hide();
    this._arenaControls.stop();
    this._arenaAnimate.stop();
  }

}


export default Arena;
