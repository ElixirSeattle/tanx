
class ChatClient {

  constructor(socket) {
    this._channel = socket.channel("chat", {});

    this._channel.join().receive("ok", () => {
      let messagesJq = $('#messages');
      let messageInputJq = $("#message-input");

      this._channel.on("user:entered", (message) => {
        messagesJq.append("<p class='row message'><span class='user-entered'>"+this._sanitize(message.username)+" entered</span></p>")
      });

      this._channel.on("user:left", (message) => {
        messagesJq.append("<p class='row message'><span class='user-left'>"+this._sanitize(message.username) +" left</span></p>")
      });

      this._channel.on("new:message", (msg) => {
        messagesJq.append("<p class='row message'><span class='username'>"+this._sanitize(msg.username)+"</span><span class='content'>"+this._sanitize(msg.content)+"</span></p>");
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
