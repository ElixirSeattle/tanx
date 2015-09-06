import {Socket} from "deps/phoenix/web/static/js/phoenix"
import "deps/phoenix_html/web/static/js/phoenix_html"

import ChatClient from "web/static/js/chat"
import Arena from "web/static/js/arena"
import PlayerList from "web/static/js/player_list"
import Settings from "web/static/js/settings"
import About from "web/static/js/about"


class TanxApp {

  constructor() {
    let socket = new Socket("/ws");
    socket.connect()

    let gameChannel = socket.channel("game", {});
    let chatClient = new ChatClient(socket);

    this._about = new About();
    this._settings = new Settings();
    this._arena = new Arena(gameChannel);
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
