
class PlayerList {

  constructor() {
    $('#tanx-player-list').hide();
  }

  start(gameChannel) {
    $('#tanx-player-list').show();
    // Make sure we get an initial view. Subsequent changes will be broadcasted
    // from the server.
    gameChannel.push("view_players", {});
    gameChannel.on("view_players", players => {
      this._clearPlayersTable();
      this._renderPlayersTable(players.p);
    });
  }

  stop() {
    $('#tanx-player-list').hide();
    this._clearPlayersTable();
  }

  _clearPlayersTable() {
    let playerTable = $('#player-rows');
    playerTable.empty();
  }

  _renderPlayersTable(players) {
    let playerTable = $('#player-rows');
    if (players.length == 0) {
      playerTable.html('<tr><td colspan="3">(No players)</td></tr>');
    } else {
      players.forEach(player => {
        let row = $('<tr>');
        if (player.me) {
          row.addClass('info');
        }
        let name = player.n || "(Anonymous coward)";
        row.html('<td>' + name + '</td><td>' + player.k +
          '</td><td>' + player.d + '</td>');
        playerTable.append(row);
      });
    }
  }

}


export default PlayerList;
