
class ChatClient {

  constructor(socket) {
    this._channel = socket.channel("chat", {});

    this._channel.join().receive("ok", () => {
      let messagesJq = $('#messages');
      let messageInputJq = $("#message-input");

      this._channel.on("user:entered", (message) => {
        messagesJq.append(
          '<div class="row"><span class="col-xs-9 col-xs-offset-3 event">' +
          this._sanitize(message.username) +
          ' entered</span></div>')
      });

      this._channel.on("user:left", (message) => {
        messagesJq.append(
          '<div class="row"><span class="col-xs-9 col-xs-offset-3 event">' +
          this._sanitize(message.username) +
          ' left</span></div>')
      });

      this._channel.on("new:message", (msg) => {
        messagesJq.append(
          '<div class="row"><span class="col-xs-3 username">' +
          this._sanitize(msg.username) +
          '</span><span class="col-xs-9 content">' +
          this._sanitize(msg.content) +
          '</span></div>');
        messagesJq.scrollTop(messagesJq[0].scrollHeight);
      });

      messageInputJq
        .off("keypress")
        .on("keypress", (event) => {
          if (event.keyCode == 13){
            this.push("new:message", {
              content: messageInputJq.val(),
              username: $("#tanx-name-field").val()
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
    });
  }


  push(event, payload) {
    if (!payload) {
      payload = {};
    }
    this._channel.push(event, payload);
  }


  _sanitize(html) {
    return $("<span/>").text(html).html();
  }

}


export default ChatClient;
