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
  // submit register form
  //
  $('#register-submit').click(function(){
    var email    = $("#register-email").val();
    var name     = $("#register-name").val();
    var twitter  = $("#register-twitter").val();
    var message  = $("#register-message").val();
    var checksum = md5( email + name + twitter + message );

    $.ajax({
      url: '/register',
      headers: {
          "Accept":       "application/json; charset=utf-8",
          "Content-Type": "application/json; charset=utf-8"
      },
      data: {
        email:    email,
        name:     name,
        twitter:  twitter,
        message:  message,
        checksum: checksum
      },
      success: function(data) {
        if (!data) {
          $("#error-dialog").html('Sending message failed. Try again.');
          $('#error-dialog').dialog('open');
          return;
        }
        if (!data.ret) {
          $("#error-dialog").html('Sending message failed. Try again.');
          $('#error-dialog').dialog('open');
          return;
        }
        if (data.ret == -1) {
          $("#error-dialog").html('Already registered. Check your e-mail or contact us.');
          $('#error-dialog').dialog('open');
          return;
        }

        $("#register-email").val('');
        $("#register-name").val('');
        $("#register-twitter").val('');
        $("#register-message").val('');
      },
      dataType: 'json'
    })

    return false;
  });

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
          $("#error-dialog").html('Sending message failed. Try again.');
          $('#error-dialog').dialog('open');
          return;
        }
        if (!data.ret) {
          $("#error-dialog").html('Sending message failed. Try again.');
          $('#error-dialog').dialog('open');
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

  //
  // error dialog
  //
  $('#error-dialog').dialog({ autoOpen: false, title: 'Error', modal: true });
});
