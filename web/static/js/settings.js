
const SHOW_FRAMERATE_INITIALLY = true;
const SHOW_JSON_INITIALLY = false;


class Settings {

  constructor() {
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

    $('#background-music-slider').slider({
      orientation: "horizontal",
      value: 50,
      step: 1,
      min: 0,
      max: 100,
      slide: function() {
        var value = $('#background-music-slider').slider('value');
        $('#background-music').prop("volume", value/100);
      }
    });
  }

}


export default Settings;
