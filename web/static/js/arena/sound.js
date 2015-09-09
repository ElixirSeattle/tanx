
class ArenaSound {

  constructor() {
    //this._explosionSound = new Audio("sounds/Explosion3.wav");
    this._backgroundMusic = $('#background-music')[0];
  }


  play(objects) {
    objects.explosions.forEach(explosion => {
      if (explosion.sound != null) {
        //this._explosionSound.play();
        new Audio("sounds/Explosion3.wav").play();
      }
    });

    this._backgroundMusic.play();
  }


  setMusicVolume(percent) {
    $('#background-music').prop("volume", percent);
  }

}


export default ArenaSound;
