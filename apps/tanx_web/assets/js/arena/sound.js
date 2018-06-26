class SoundPool {

  constructor(url) {
    this._url = url;
    this._volume = 1.0;
    this._mute = false;
    this._idle = [];
    this._playing = [];
    this._ensureAvailable();
  }

  _ensureAvailable() {
    if (this._idle.length == 0) {
      let audio = new Audio(this._url);
      audio.volume = this._mute ? 0 : this._volume;
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
    if (!this._mute) {
      this._playing.forEach(audio => {
        audio.volume = percent;
      });
      this._idle.forEach(audio => {
        audio.volume = percent;
      });
    }
  }

  getVolume() {
    return this._volume;
  }

  setMute(mute) {
    this._mute = mute;
    let volume = mute ? 0 : this._volume;
    this._playing.forEach(audio => {
      audio.volume = volume;
    });
    this._idle.forEach(audio => {
      audio.volume = volume;
    });
  }
}


class ArenaSound {

  constructor() {
    this._backgroundMusic = $('#background-music')[0];
    this._explosions = new SoundPool("sounds/Explosion3.wav");
    this._musicVolume = 1.0;
    this._musicMute = false;
  }

  play(objects) {
    objects.e.forEach(explosion => {
      if (explosion.sound != null) {
        this._explosions.startPlaying();
      }
    });

    this._backgroundMusic.play();
  }

  getMusicVolume() {
    return this._musicVolume;
  }

  getSoundVolume() {
    return this._explosions.getVolume();
  }

  setMusicVolume(percent) {
    this._musicVolume = percent;
    if (!this._musicMute) {
      $('#background-music').prop("volume", percent);
    }
  }

  setMusicMute(mute) {
    this._musicMute = mute;
    let volume = mute ? 0 : this._musicVolume;
    $('#background-music').prop("volume", volume);
  }

  setSoundVolume(percent) {
    this._explosions.setVolume(percent);
  }

  setSoundMute(mute) {
    this._explosions.setMute(mute);
  }

}


export default ArenaSound;
