
class Settings {

  constructor() {
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
