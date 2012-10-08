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

  var attachPath = function(path) {
    path = path.replace(/^\//, '');
    if (location.href.match(/\/$/)) {
      return "" + location.href + path + "/";
    } else {
      return "" + location.href + "/" + path + "/";
    }
  }

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
      url: attachPath('/register'),
      type: 'POST',
      headers: {
          "Accept":       "application/json; charset=utf-8"
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
      url: attachPath('/contact'),
      type: 'POST',
      headers: {
          "Accept":       "application/json; charset=utf-8"
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

  //
  // attenders
  //
  var intervalSecond = 10;
  var loop_attenders = function() {
    $.ajax({
      type: 'GET',
      url: attachPath('/attenders'),
      headers: {
        Accept: 'application/json'
      },
      error: function(jqXHR, textStatus, errorThrown) {
        console.log(textStatus);
      },
      success: function(data, textStatus, jqXHR) {
        $("#section-attender .content div.row:nth-child(3)").empty()
        $("#section-attender .content div.row:nth-child(5)").empty()
        var html, user, userid, _i, _j, _len, _len1, _ref, _ref1;

        _ref = data.confirmed;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          user = _ref[_i];
          userid = ("" + user.email).replace(/@.*/, '');
          html = "<div class=\"col_2\">\n  <div class=\"profile confirmed\">\n    <p>\n      <img alt=\"" + userid + "\" src=\"http://www.gravatar.com/avatar/" + (md5(user.email)) + "?d=" + (encodeURI('http://st.pimg.net/perlweb/images/camel_head.v25e738a.png')) + "&s=132\" class=\"profile-confirmed-image\" style=\"height: 132px; width: 132px;\">\n      <br>\n      " + userid + "\n    </p>\n    <p>\n    </p>\n  </div>\n</div>";
          $("#section-attender .content div.row:nth-child(3)").append(html);
        }

        _ref1 = data.waiting;
        for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
          user = _ref1[_j];
          userid = ("" + user.email).replace(/@.*/, '');
          html = "<div class=\"col_1\">\n  <div class=\"profile waiting\">\n    <p>\n      <img alt=\"" + userid + "\" src=\"http://www.gravatar.com/avatar/" + (md5(user.email)) + "?d=" + (encodeURI('http://st.pimg.net/perlweb/images/camel_head.v25e738a.png')) + "&s=47\" class=\"profile-waiting-image\" style=\"height: 47px; width: 47px;\">\n      <br>\n      " + userid + "\n    </p>\n    <p>\n    </p>\n  </div>\n</div>";
          $("#section-attender .content div.row:nth-child(5)").append(html);
        }
      }
    });
  };
  loop_attenders.call(this);
  setInterval(loop_attenders, intervalSecond * 1000);
});
