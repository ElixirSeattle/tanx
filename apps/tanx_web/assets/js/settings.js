
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

    let backgroundMusicSlider = new Slider('#background-music-slider', {
      id: 'background-music-slider-elem',
      min: 0,
      max: 100,
      step: 1,
      value: 100,
      tooltip: 'hide'
    });
    backgroundMusicSlider.on('slide', () => {
      arenaSound.setMusicVolume(backgroundMusicSlider.getValue() / 100);
    });

    $('#music-mute-checkbox').prop('checked', MUTE_MUSIC_INITIALLY);
    arenaSound.setMusicMute(MUTE_MUSIC_INITIALLY);
    $('#music-mute-checkbox').on('change', event => {
      arenaSound.setMusicMute($('#music-mute-checkbox').prop('checked'));
    });

    let soundFxSlider = new Slider('#fx-volume-slider', {
      id: 'fx-slider-elem',
      min: 0,
      max: 100,
      step: 1,
      value: 100,
      tooltip: 'hide'
    });
    soundFxSlider.on('slide', () => {
      arenaSound.setSoundVolume(soundFxSlider.getValue() / 100);
    });

    $('#fx-mute-checkbox').prop('checked', MUTE_SOUND_INITIALLY);
    arenaSound.setSoundMute(MUTE_SOUND_INITIALLY);
    $('#fx-mute-checkbox').on('change', event => {
      arenaSound.setSoundMute($('#fx-mute-checkbox').prop('checked'));
    });
  }

}


export default Settings;
