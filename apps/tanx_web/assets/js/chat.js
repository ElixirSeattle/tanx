
class ChatClient {

  constructor() {
    this._channel = null;

    $('#tanx-chat').hide();

    let messageInputJq = $("#message-input");
    messageInputJq
      .off("keypress")
      .on("keypress", (event) => {
        if (event.keyCode == 13){
          this.push("message", {
            content: messageInputJq.val(),
            username: this._curPlayerName()
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


  start(chatChannel) {
    this._channel = chatChannel;

    $('#tanx-chat').show();

    let messagesJq = $('#messages');
    messagesJq.empty();

    chatChannel.on("entered", (message) => {
      messagesJq.append(
        '<div class="row"><span class="col-xs-9 col-xs-offset-3 event">' +
        this._sanitize(message.username) +
        ' entered</span></div>')
    });

    chatChannel.on("left", (message) => {
      messagesJq.append(
        '<div class="row"><span class="col-xs-9 col-xs-offset-3 event">' +
        this._sanitize(message.username) +
        ' left</span></div>')
    });

    chatChannel.on("message", (msg) => {
      messagesJq.append(
        '<div class="row"><span class="col-xs-3 username">' +
        this._sanitize(msg.username) +
        '</span><span class="col-xs-9 content">' +
        this._sanitize(msg.content) +
        '</span></div>');
      messagesJq.scrollTop(messagesJq[0].scrollHeight);
    });

    this.push("join", {name: this._curPlayerName()});
  }


  stop() {
    $('#tanx-chat').hide();
    this.push("leave", {name: this._curPlayerName()});
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


  _curPlayerName() {
    return $("#tanx-name-field").val();
  }

  _sanitize(html) {
    return $("<span/>").text(html).html();
  }

}


export default ChatClient;
