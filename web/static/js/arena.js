import ArenaStructure from "web/static/js/arena/structure"
import ArenaAnimate from "web/static/js/arena/animate"
import ArenaControls from "web/static/js/arena/controls"


class Arena {

  constructor(gameChannel) {
    this._gameChannel = gameChannel;

    this._arenaControls = new ArenaControls(gameChannel);
    this._arenaAnimate = new ArenaAnimate(gameChannel);

    this._gameChannel.on("view_structure", structure => {
      let arenaStructure = new ArenaStructure(structure);
      this._arenaControls.start(arenaStructure);
      this._arenaAnimate.start(arenaStructure);
    });
  }


  start() {
    this._gameChannel.push("view_structure", {});
  }


  stop() {
    this._arenaControls.stop();
    this._arenaAnimate.stop();
  }

}


export default Arena;
