
const SHOW_FRAMERATE_INITIALLY = true;
const SHOW_JSON_INITIALLY = false;

const MUTE_MUSIC_INITIALLY = true;
const MUTE_SOUND_INITIALLY = true;


class Settings {

  constructor(arenaSound) {
    $('#settings-modal').on('shown.bs.modal', event => {
      $('#settings-modal button').focus();
    });

    $('#show-framerate-checkbox').prop('checked', SHOW_FRAMERATE_INITIALLY);
    $('#tanx-framerate').toggle(SHOW_FRAMERATE_INITIALLY);
    $('#show-framerate-checkbox').on('change', event => {
      $('#tanx-framerate').toggle($('#show-framerate-checkbox').prop('checked'));
    });

    $('#show-arena-json-checkbox').prop('checked', SHOW_JSON_INITIALLY);
    $('#tanx-arena-json').toggle(SHOW_JSON_INITIALLY);
    $('#show-arena-json-checkbox').on('change', event => {
      $('#tanx-arena-json').toggle($('#show-arena-json-checkbox').prop('checked'));
    });

    $('#background-music-slider')
      .val(arenaSound.getMusicVolume())
      .on('change', event => {
        arenaSound.setMusicVolume($('#background-music-slider').val());
      });

    $('#fx-volume-slider')
      .val(arenaSound.getSoundVolume())
      .on('change', event => {
        arenaSound.setSoundVolume($('#fx-volume-slider').val());
      });

    $('#music-mute-checkbox').prop('checked', MUTE_MUSIC_INITIALLY);
    arenaSound.setMusicMute(MUTE_MUSIC_INITIALLY);
    $('#music-mute-checkbox').on('change', event => {
      arenaSound.setMusicMute($('#music-mute-checkbox').prop('checked'));
    });

    $('#fx-mute-checkbox').prop('checked', MUTE_SOUND_INITIALLY);
    arenaSound.setSoundMute(MUTE_SOUND_INITIALLY);
    $('#fx-mute-checkbox').on('change', event => {
      arenaSound.setSoundMute($('#fx-mute-checkbox').prop('checked'));
    });
  }

}


export default Settings;
