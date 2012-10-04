$(document).ready(function() {
  //
  // onePageNav and scrollTo plugin
  //
  $('nav').onePageNav({ currentClass: 'active' });
  $('#subnav').click(function(){
    $.scrollTo('#section-register', 800);
    return false;
  });

  //
  // fix height for webkit based browser
  //
  var confirmed = $('.profile-confirmed-image').width();
  var waiting  = $('.profile-waiting-image').width();
  $('.profile-confirmed-image').css({'height': confirmed+'px'});
  $('.profile-waiting-image').css({'height': waiting+'px'});

  //
  // submit contact form
  //
  $('#contact-submit').click(function(){
    var email    = $("#contact-email").val();
    var subject  = $("#contact-subject").val();
    var message  = $("#contact-message").val();
    var checksum = md5( email + subject + message );

    $.ajax({
      url: '/contact',
      headers: {
          "Accept":       "application/json; charset=utf-8",
          "Content-Type": "application/json; charset=utf-8"
      },
      data: {
        email:    email,
        subject:  subject,
        message:  message,
        checksum: checksum
      },
      success: function(data) {
        if (!data) {
          alert('Sending message failed. Try again.');
          return;
        }
        if (!data.ret) {
          alert('Sending message failed. Try again.');
          return;
        }

        $("#contact-email").val('');
        $("#contact-subject").val('');
        $("#contact-message").val('');
      },
      dataType: 'json'
    })

    return false;
  });
});
