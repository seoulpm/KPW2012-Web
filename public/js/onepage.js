$(document).ready(function() {
  $('nav').onePageNav({ currentClass: 'active' });
  $('#subnav').click(function(){
    $.scrollTo('#section-register', 800);
    return false;
  });

  var confimed = $('.profile-confirmed-image').width();
  var waiting  = $('.profile-waiting-image').width();
  $('.profile-confirmed-image').css({'height':confirmed+'px'});
  $('.profile-waiting-image').css({'height':waiting+'px'});
});
