class SoundPool {

  constructor(url) {
    this._url = url;
    this._volume = 1.0;
    this._idle = [];
    this._playing = [];
    this._ensureAvailable();
  }

  _ensureAvailable() {
    if (this._idle.length == 0) {
      let audio = new Audio(this._url);
      audio.volume = this._volume;
      this._idle.push(audio);
      $(audio).on('ended', event => {
        let index = this._playing.indexOf(audio);
        if (index >= 0) {
          this._playing.splice(index, 1);
          this._idle.push(audio);
        }
      });
    }
  }

  startPlaying() {
    this._ensureAvailable();
    let audio = this._idle.pop();
    audio.play();
    this._playing.push(audio);
  }

  setVolume(percent) {
    this._volume = percent;
    this._playing.forEach(audio => {
      audio.volume = percent;
    });
    this._idle.forEach(audio => {
      audio.volume = percent;
    });
  }
}


class ArenaSound {

  constructor() {
    this._backgroundMusic = $('#background-music')[0];
    this._explosions = new SoundPool("sounds/Explosion3.wav");
  }


  play(objects) {
    objects.explosions.forEach(explosion => {
      if (explosion.sound != null) {
        this._explosions.startPlaying();
      }
    });

    this._backgroundMusic.play();
  }


  setMusicVolume(percent) {
    $('#background-music').prop("volume", percent);
  }

  setSoundVolume(percent) {
    this._explosions.setVolume(percent);
  }

}


export default ArenaSound;
