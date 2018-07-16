
import {Socket} from "phoenix"
import "phoenix_html"

import ChatClient from "js/chat"
import Arena from "js/arena"
import ArenaSound from "js/arena/sound"
import Lobby from "js/lobby"
import PlayerList from "js/player_list"
import Settings from "js/settings"
import About from "js/about"


class TanxApp {

  constructor() {
    let socket = new Socket("/ws", {
      reconnectAfterMs: function(tries) {
        return [1, 100, 200, 400, 800][tries - 1] || 1000;
      }
    });
    socket.connect();

    let arenaSound = new ArenaSound();

    this._lobby = new Lobby(socket);
    this._playerList = new PlayerList();
    this._chatClient = new ChatClient();
    this._about = new About();
    this._settings = new Settings(arenaSound);
    this._arena = new Arena(arenaSound);

    this._lobby.onJoin((gameId, gameChannel, chatChannel) => {
      this._playerList.start(gameChannel);
      this._chatClient.start(chatChannel);
      this._arena.start(gameChannel);
    });
    this._lobby.onLeave((gameId, gameChannel, chatChannel) => {
      this._playerList.stop();
      this._chatClient.stop();
      this._arena.stop();
    });
    this._lobby.onRejoin((gameId, gameChannel, chatChannel) => {
      this._playerList.restart(gameChannel);
      this._arena.restart(gameChannel);
    });
  }

}

let app = new TanxApp();
window.tanxApp = app

export default app;
