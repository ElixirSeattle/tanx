import ArenaStructure from "js/arena/structure"
import ArenaAnimate from "js/arena/animate"
import ArenaControls from "js/arena/controls"


class Arena {

  constructor(arenaSound) {
    this._arenaControls = new ArenaControls();
    this._arenaAnimate = new ArenaAnimate(arenaSound);
  }


  start(gameChannel) {
    gameChannel.push("view_structure", {});
    gameChannel.on("view_structure", structure => {
      let arenaStructure = new ArenaStructure(structure);
      this._arenaControls.start(gameChannel, arenaStructure);
      this._arenaAnimate.start(gameChannel, arenaStructure);
    });
  }


  stop() {
    this._arenaControls.stop();
    this._arenaAnimate.stop();
  }

}


export default Arena;
