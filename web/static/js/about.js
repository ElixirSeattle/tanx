
class About {

  constructor() {
    $('#about-modal')
      .on('shown.bs.modal', event => {
        $('#about-modal button').focus();
      })
      .modal('show');
  }

}


export default About;
