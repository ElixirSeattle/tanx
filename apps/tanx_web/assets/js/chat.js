
class ChatClient {

  constructor() {
    this._channel = null;

    $('#tanx-chat').hide();

    let messageInputJq = $("#message-input");
    messageInputJq
      .off("keypress")
      .on("keypress", (event) => {
        if (event.keyCode == 13){
          this.push("chat_message", {
            content: messageInputJq.val()
          });
          messageInputJq.val("");
        }
      })
      .on('keydown', (event) => {
        event.stopPropagation();
      })
      .on('keyup', (event) => {
        event.stopPropagation();
      });
  }


  start(gameChannel) {
    this._channel = gameChannel;

    $('#tanx-chat').show();

    let messagesJq = $('#messages');
    messagesJq.empty();

    gameChannel.on("chat_entered", (message) => {
      messagesJq.append(
        '<div class="row"><div class="col-9 offset-3 event">' +
        this._display_name(message.name) +
        ' entered</div></div>')
    });

    gameChannel.on("chat_left", (message) => {
      messagesJq.append(
        '<div class="row"><div class="col-9 offset-3 event">' +
        this._display_name(message.name) +
        ' left</div></div>')
    });

    gameChannel.on("chat_renamed", (message) => {
      messagesJq.append(
        '<div class="row"><div class="col-9 offset-3 event">' +
        this._display_name(message.old_name) +
        ' is now known as ' +
        this._display_name(message.name) +
        '.</div></div>')
    });

    gameChannel.on("chat_message", (msg) => {
      messagesJq.append(
        '<div class="row"><div class="col-3 username">' +
        this._display_name(msg.name) +
        '</div><div class="col-9 content">' +
        this._sanitize(msg.content) +
        '</div></div>');
      messagesJq.scrollTop(messagesJq[0].scrollHeight);
    });

    this.push("chat_join", {});
  }


  stop() {
    $('#tanx-chat').hide();
    this.push("chat_leave", {});
    this._channel = null;
  }


  push(event, payload) {
    if (!payload) {
      payload = {};
    }
    if (this._channel != null) {
      this._channel.push(event, payload);
    }
  }


  _display_name(text) {
    return this._sanitize(text) || "Anonymous Coward";
  }


  _sanitize(str) {
    return $("<span>").text(str).html();
  }

}


export default ChatClient;
