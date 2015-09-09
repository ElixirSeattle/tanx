
class ArenaSound {

  constructor() {
    //this._explosionSound = new Audio("sounds/Explosion3.wav");
    this._backgroundMusic = $('#background-music')[0];
    this._fxVolume = 1.0;
  }


  play(objects) {
    objects.explosions.forEach(explosion => {
      if (explosion.sound != null) {
        //this._explosionSound.play();
        let audio = new Audio("sounds/Explosion3.wav");
        audio.volume = this._fxVolume;
        audio.play();
      }
    });

    this._backgroundMusic.play();
  }


  setMusicVolume(percent) {
    $('#background-music').prop("volume", percent);
  }

  setSoundVolume(percent) {
    this._fxVolume = percent;
  }

}


export default ArenaSound;
