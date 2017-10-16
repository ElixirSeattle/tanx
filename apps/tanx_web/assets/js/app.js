
import {Socket} from "phoenix"
import "phoenix_html"

import ChatClient from "js/chat"
import Arena from "js/arena"
import ArenaSound from "js/arena/sound"
import PlayerList from "js/player_list"
import Settings from "js/settings"
import About from "js/about"


class TanxApp {

  constructor() {
    let socket = new Socket("/ws");
    socket.connect()

    let gameChannel = socket.channel("game", {});
    let chatClient = new ChatClient(socket);
    let arenaSound = new ArenaSound();

    this._about = new About();
    this._settings = new Settings(arenaSound);
    this._arena = new Arena(gameChannel, arenaSound);
    this._playerList = new PlayerList(gameChannel, chatClient);

    this._playerList.onJoin(() => {
      this._arena.start();
    });
    this._playerList.onLeave(() => {
      this._arena.stop();
    });
  }

}


let app = new TanxApp();
window.tanxApp = app;

export default app;
