#!/usr/bin/env perl

use 5.010;
use utf8;

use Mojolicious::Lite;
use Mojo::Util qw( md5_sum encode url_escape );

use DBIx::Connector;
use DateTime;
use Gravatar::URL;
use String::Random::NiceURL qw( id );
use Text::MultiMarkdown;
use Try::Tiny;

my %DEFAULT_STASH = (
    active => q{},
    %{ plugin 'Config' },
);
app->defaults(%DEFAULT_STASH);

my $m = Text::MultiMarkdown->new(
    tab_width     => 2,
    use_wikilinks => 0,
);

my $conn = DBIx::Connector->new( @{ app->config->{connect} } );
$conn->dbh;
die "cannot connect to database\n" unless $conn->connected;

helper sendmail => sub {
    my ( $self, %params ) = @_;

    my $from    = $params{from}    || $self->app->config->{email}{username} || q{};
    my $to      = $params{to}      || q{};
    my $subject = $params{subject} || q{};
    my $message = $params{message} || q{};

    $self->app->log->warn("invalid email from"),    return unless $from;
    $self->app->log->warn("invalid email to"),      return unless $to;
    $self->app->log->warn("invalid email subject"), return unless $subject;
    $self->app->log->warn("invalid email message"), return unless $message;

    #
    # go ahead!
    #
    # Send mail via job-queue, direct sending,
    # using file or etc... whatever you want. ;-)
    #
    $self->app->log->debug("send mail [$from] -> [$to]");
};

helper checksum => sub {
    my ( $self, @strings ) = @_;

    return unless @strings;
    return md5_sum( encode('UTF-8', join(q{}, @strings)) );
};

helper get_gravatar => sub {
    my ( $self, %opts ) = @_;

    $opts{default} ||= 'http://upload.wikimedia.org/wikipedia/en/e/e0/Programming-republic-of-perl.png';
    my $url = gravatar_url(%opts);

    return $url;
};

helper get_attendees => sub {
    my $self = shift;

    my (@confirmed, @waiting);
    my $rv = $conn->run(fixup => sub {
        try {
            my $sth = $_->prepare( q{ SELECT * FROM register ORDER BY status, updated_on } );
            my $rv = $sth->execute;
            while (my $data = $sth->fetchrow_hashref) {
                given ( $data->{status} ) {
                    push @waiting,   $data when 'waiting';
                    push @confirmed, $data when 'confirmed';
                }
            }

            $rv;
        };
    });

    return +{
        confirmed => \@confirmed,
        waiting   => \@waiting,
    };
};

helper add_register => sub {
    my ( $self, $email, $name, $twitter, $message, $checksum ) = @_;

    $self->app->log->warn("invalid email $email"),       return unless $email;
    $self->app->log->warn("invalid name $name"),         return unless $name;
    $self->app->log->warn("invalid checksum $checksum"), return
        unless $checksum eq $self->checksum( $email, $name, $twitter, $message );

    my $nick = q{};
    if ($twitter) {
        $twitter =~ s/\s+//;
        if ($twitter =~ m{^https?://.*?twitter.com/(?:[#]!)*([^/]+)}) {
            $nick = $1;
        }
        elsif ($twitter =~ m{^\@(.+)}) {
            $nick    = $1;
            $twitter = $1;
        }
        else {
            $nick = $twitter;
        }
    }
    else {
        $nick = $email;
        $nick =~ s/\@.*//;
    }

    my $ret = $conn->txn(fixup => sub {
        my $ret = try {
            my $sth = $_->prepare( q{ SELECT * FROM register WHERE email=? } );
            $sth->execute( $email );
            my $ret = $sth->fetchrow_hashref;

            if (!$ret) {
                my $sth = $_->prepare(q{
                    INSERT INTO register
                        (email,name,twitter,nick,message,status,waiting,created_on)
                        VALUES (?,?,?,?,?,?,?,?)
                });
                $ret = $sth->execute(
                    $email,
                    $name,
                    $twitter,
                    $nick,
                    $message,
                    'registered',
                    id(64),
                    DateTime->now->format_cldr("yyyy-MM-dd HH:mm::ss"),
                );
            }
            else {
                $ret = -1;
            }

            $ret;
        };

        return $ret;
    });

    if ( $ret && $ret > 0 ) {
        $conn->txn(fixup => sub {
            try {
                my $sth = $_->prepare( q{ SELECT * FROM register WHERE email=? } );
                $sth->execute( $email );
                my $person = $sth->fetchrow_hashref;

                if ($person) {
                    $self->sendmail(
                        from    => $self->app->config->{email}{username},
                        to      => $person->{email},
                        subject => $self->app->config->{email}{register_subject},
                        message => sprintf(
                            $self->app->config->{email}{register_message},
                            $person->{name},
                            url_escape( $person->{email} ),
                            $person->{waiting},
                            url_escape( $person->{email} ),
                            $person->{waiting},
                        ),
                    );
                }
            };
        });
    }

    return $ret;
};

helper add_contact => sub {
    my ( $self, $email, $subject, $message, $checksum ) = @_;

    $self->app->log->warn("invalid email $email"),       return unless $email;
    $self->app->log->warn("invalid subject $subject"),   return unless $subject;
    $self->app->log->warn("invalid message $message"),   return unless $message;
    $self->app->log->warn("invalid checksum $checksum"), return
        unless $checksum eq $self->checksum( $email, $subject, $message );

    my $rv = $conn->run(fixup => sub {
        try {
            my $sth = $_->prepare('INSERT INTO contact (email,subject,message,created_on) VALUES (?,?,?,?)');
            my $rv = $sth->execute($email, $subject, $message, DateTime->now->format_cldr("yyyy-MM-dd HH:mm::ss"));
            $rv;
        };
    });

    return $rv;
};

helper markdown => sub {
    my ( $self, $text ) = @_;
    return unless $text;
    my $html = $m->markdown($text);
    return $html;
};

get('/' => 'index');

post '/register' => sub {
    my $self = shift;

    my $email    = $self->param('email')    || q{};
    my $name     = $self->param('name')     || q{};
    my $twitter  = $self->param('twitter')  || q{};
    my $message  = $self->param('message')  || q{};
    my $checksum = $self->param('checksum') || q{};

    my $ret = $self->add_register(
        $email,
        $name,
        $twitter,
        $message,
        $checksum,
    );

    $self->respond_to( json => { json => { ret => $ret ? $ret : 0 } } );
};

get '/register/waiting' => sub {
    my $self = shift;

    my $email    = $self->param('email')   || q{};
    my $waiting  = $self->param('waiting') || q{};

    my $person = $conn->run(fixup => sub {
        try {
            my $sth = $_->prepare( q{ SELECT * FROM register WHERE email=? } );
            $sth->execute( $email );
            my $ret = $sth->fetchrow_hashref;
            $ret;
        };
    });

    my $update;
    if (
        $person
        && $person->{waiting}
        && $person->{waiting} eq $waiting
        && $person->{status}
        && $person->{status} eq 'sent'
    ) {
        $update = $conn->run(fixup => sub {
            try {
                my $sth = $_->prepare(q{
                    UPDATE register SET status=?, updated_on=? WHERE email=?
                });
                $sth->execute(
                    'waiting',
                    DateTime->now->format_cldr("yyyy-MM-dd HH:mm::ss"),
                    $email,
                );
            };
        });
    }

    if ($update) {
        $self->app->log->debug("[$email] is now waiting list");
    }
    else {
        $self->app->log->debug("[$email] nothing change");
    }

    $self->redirect_to( '/#section-attendee' );
};

post '/contact' => sub {
    my $self = shift;

    my $email    = $self->param('email')    || q{};
    my $subject  = $self->param('subject')  || q{};
    my $message  = $self->param('message')  || q{};
    my $checksum = $self->param('checksum') || q{};

    my $ret = $self->add_contact(
        $email,
        $subject,
        $message,
        $checksum,
    );

    $self->respond_to( json => { json => { ret => $ret ? 1 : 0 } } );
};

get '/attendees' => sub {
    my $self = shift;

    my $attendees = $self->get_attendees;

    $self->respond_to( json => { json => $attendees } );
};

get '/twitter-list' => sub {
    my $self = shift;

    my @twitters;
    $conn->run(fixup => sub {
        try {
            my $sth = $_->prepare( q{ SELECT * FROM register } );
            $sth->execute;
            while (my $data = $sth->fetchrow_hashref) {
                push @twitters, $data->{twitter} if $data->{twitter};
            }
        };
    });

    $self->respond_to( json => { json => \@twitters } );
};

app->secret( app->defaults->{secret} );
app->start;

__DATA__

@@ section-home.html.ep
    <section id="section-home" class="page-section">
      <div class="content row">
        <div class="row">
          <div class="col_8 last">
            <h1>Korean <span class="text-color">Perl</span> Workshop 2012</h1>
            <h2>
              on <span class="text-color">Sat. Oct. 20th, 2012</span> between <span class="text-color">13:30 - 20:00</span> <br />
              at <a href="http://www.cnnthebiz.com/booth/booth01_8.asp">CNN the Biz 강남교육연수 센터</a>
              <span class="text-color">
                <a href="https://maps.google.com/maps?q=%EC%84%9C%EC%9A%B8%ED%8A%B9%EB%B3%84%EC%8B%9C+%EA%B0%95%EB%82%A8%EA%B5%AC+%EC%97%AD%EC%82%BC%EB%8F%99+619-16&hl=ko&ie=UTF8&ll=37.5021,127.027016&spn=0.174316,0.41851&sll=37.501433,127.026848&sspn=0.005481,0.013078&hnear=%EB%8C%80%ED%95%9C%EB%AF%BC%EA%B5%AD+%EC%84%9C%EC%9A%B8%ED%8A%B9%EB%B3%84%EC%8B%9C+%EA%B0%95%EB%82%A8%EA%B5%AC+%EC%97%AD%EC%82%BC%EB%8F%99+619-16&t=m&z=12&iwloc=A"><i class=" icon-map-marker"></i></a>
              </span>
              <br />
              <span class="text-color">Register</span> Now!
            </h2>
          </div>
        </div>
        <div class="row">
          <div class="col_4 last">
            <a class="large-circular-down-arrow" href="#section-register" id="subnav"></a>
          </div>
        </div>
      </div>
    </section>


@@ section-register.html.ep
    <section id="section-register" class="page-section">
      <header class="row">
        <div class="col_6 last"> <h1>Register.</h1> </div>
      </header>
      <div class="content">
        <form action="/register" method="post">
          <div class="row">
            <div class="col_6 pre_4" style="display: none;">
              <p style="hidden">
                KPW 2012의 참가비는 <span class="text-color">1만원</span>입니다.
                아래 등록 양식을 작성하신 후 참가비를 납부해주세요.
                납부 완료후 확인이 끝나면 <span class="text-color">"확정"</span>
                명단에 들어갑니다.  납부가 완료되지 않으면
                <span class="text-color">"대기"</span> 명단에 들어갑니다.
              </p>
              <p>
                <span class="text-color">우리은행: 461-162011-02-101 (김도형)</span>
              </p>
            </div>
            <div class="col_6 pre_4">
              <p>
                <span class="text-color">등록 신청</span>은 모두 <span class="text-color">마감</span> 되었습니다.
                성원에 감사드립니다.
              </p>
              <p>
                정원을 제외한 인원은 좌석이 없습니다.
                그럼에도 불구하고 <span class="text-color">스탠딩</span> 또는
                <span class="text-color">바닥</span>에 앉아서라도
                워크샵에 참석하시고 싶으신 분은 <span class="text-color">연락</span>바랍니다.
              </p>
            </div>
          </div>
          <div class="row">
            <div class="col_4">
              <label for="register-email">Email</label>
            </div>
            <div class="col_6 suf_2 last">
              <div class="form-holder">
                <input id="register-email" name="register-email" type="text" placeholder="(required) 등록 확인 메일을 전송할 주소" disabled />
              </div>
            </div>
          </div>
          <div class="row">
            <div class="col_4">
              <label for="register-name">Name</label>
            </div>
            <div class="col_6 suf_2 field-holder last">
              <div class="form-holder">
                <input id="register-name" name="register-name" type="text" maxlength="150" placeholder="(required) 입금자명과 동일" disabled />
              </div>
            </div>
          </div>
          <div class="row">
            <div class="col_4">
              <label for="register-twitter">Twitter ID</label>
            </div>
            <div class="col_6 suf_2 field-holder last">
              <div class="form-holder">
                <input id="register-twitter" name="register-twitter" type="text" maxlength="150" placeholder="(optional) @" disabled />
              </div>
            </div>
          </div>
          <div class="row">
            <div class="col_4">
              <label for="register-message">Message</label>
            </div>
            <div class="col_6 suf_2 field-holder last">
              <div class="form-holder">
                <textarea id="register-message" name="register-message" rows="10" cols="40" placeholder="(optional) 행사에 바라는 점" disabled></textarea>
              </div>
            </div>
          </div>
          <div class="row">
            <div class="col_1 pre_9">
              <a href="#section-register" id="register-submit" class="submit-button suf_1" disabled>Submit</a>
            </div>
          </div>
        </form>
      </div>
    </section>


@@ section-schedule.html.ep
    <section id="section-schedule" class="page-section-scroll">
      <header class="row">
        <div class="col_6 last">
          <h1>Schedule.</h1>
        </div>
      </header>
      <div class="content">
        % for my $text (@$schedules) {
          <div class="row">
            <div class="col_8 pre_1">
              <%== markdown $text %>
            </div> <!-- col_5 -->
          </div> <!-- row -->
        % }
        <div class="spacer"></div>
      </div>
    </section>


@@ section-attendee.html.ep
    <section id="section-attendee" class="page-section-scroll">
      <header class="row">
        <div class="col_6 last">
        <h1>Attendees.</h1>
        </div>
      </header>
      <div class="content">

        <div class="row">
          <div class="col_8 pre_1">
            <p>
              프로필 사진은 <a href="http://en.gravatar.com/" alt="Gravatar">Gravatar</a>에
              등록된 사진으로 표시됩니다.
              지금 바로 <a href="http://en.gravatar.com/" alt="Gravatar">Gravatar</a>에
              여러분의 전자우편 주소와 프로필 사진을 등록하세요! :-)
            </p>
          </div>
        </div> <!-- row -->

        %
        %# get attendees
        %
        % my $attendees = get_attendees;

        <div class="row">
          <div class="col_8 pre_1">
            <h2>Confirmed.</h2>
          </div>
        </div> <!-- row -->

        <div class="row">
          % for my $person ( @{ $attendees->{confirmed} } ) {
            % my $gravatar = get_gravatar( email => $person->{email} );
            <div class="col_2">
              <div class="profile confirmed">
                <p>
                  <img class="profile-confirmed-image" src="<%= $gravatar %>" alt="<%= $person->{nick} %>" />
                  <br/>
                  <%= $person->{nick} %>
                </p>
              </div>
            </div>
          % }
        </div>

        <div class="row">
          <div class="col_8 pre_1">
            <h2>Waiting.</h2>
          </div>
        </div> <!-- row -->

        <div class="row">
          % for my $person ( @{ $attendees->{waiting} } ) {
            % my $gravatar = get_gravatar( email => $person->{email} );
            <div class="col_1">
              <div class="profile waiting">
                <p>
                  <img class="profile-waiting-image" src="<%= $gravatar %>" alt="<%= $person->{nick} %>" />
                  <br/>
                  <%= $person->{nick} %>
                </p>
              </div>
            </div>
          % }
        </div>

        <div class="spacer"></div>
      </div>
    </section>


@@ section-faq.html.ep
    <section id="section-faq" class="page-section-scroll">
      <header class="row">
        <div class="col_6 last">
          <h1>FAQ.</h1>
        </div>
      </header>
      <div class="content">
        % for my $text (@$faqs) {
          <div class="row">
            <div class="col_8 pre_1">
              <%== markdown $text %>
            </div> <!-- col_5 -->
          </div> <!-- row -->
        % }
        <div class="spacer"></div>
      </div>
    </section>


@@ section-contact.html.ep
    <section id="section-contact" class="page-section">
      <header class="row">
        <div class="col_6 last"> <h1>Contact.</h1> </div>
      </header>
      <div class="content">
        <form method="post">
          <div class="row">
            <div class="col_6 pre_4">
              <p>
                <span class="text-color">KPW 2012</span>이나
                <span class="text-color">Seoul.pm</span>에 대해
                궁금한 점이 있거나 전하고 싶은 말이 있다면 알려주세요.
                저희는 여러분의 소중한 의견을 듣고 싶습니다.
              </p>
            </div>
          </div>
          <div class="row">
            <div class="col_4">
              <label for="contact-email">Email</label>
            </div>
            <div class="col_6 suf_2 last">
              <div class="form-holder">
                <input id="contact-email" name="contact-email" type="text" placeholder="답장을 받을 메일 주소" />
              </div>
            </div>
          </div>
          <div class="row">
            <div class="col_4">
              <label for="contact-subject">Subject</label>
            </div>
            <div class="col_6 suf_2 field-holder last">
              <div class="form-holder">
                <input id="contact-subject" name="contact-subject" type="text" maxlength="128" placeholder="제목을 입력하세요." />
              </div>
            </div>
          </div>
          <div class="row">
            <div class="col_4">
              <label for="contact-message">Message</label>
            </div>
            <div class="col_6 suf_2 field-holder last">
              <div class="form-holder">
                <textarea id="contact-message" name="contact-message" rows="10" cols="40" placeholder="내용을 입력하세요."></textarea>
              </div>
            </div>
          </div>
          <div class="row">
            <div class="col_1 pre_9">
              <a href="#section-contact" id="contact-submit" class="submit-button suf_1">Submit</a>
            </div>
          </div>
        </form>
      </div>

      %= include 'layouts/footer'

    </section>


@@ index.html.ep
% layout 'onepage',
%   csses => [ qw( css/boilerplate.css css/onepage.css  ) ],
%   jses  => [ qw( jquery.nav.js jquery.scrollTo.js md5.min.js onepage.js ) ];
%
% title 'Korean Perl Workshop 2012';
<div id="error-dialog"><p id="error-message"></p></div>
<div id="success-dialog"><p id="success-message"></p></div>
%= include 'section-home'
%= include 'section-register'
%= include 'section-schedule'
%= include 'section-attendee'
%= include 'section-faq'
%= include 'section-contact'


@@ layouts/onepage.html.ep
<!DOCTYPE html>
<!--[if lt IE 7]> <html class="no-js lt-ie9 lt-ie8 lt-ie7" lang="en"> <![endif]-->
<!--[if IE 7]>    <html class="no-js lt-ie9 lt-ie8" lang="en"> <![endif]-->
<!--[if IE 8]>    <html class="no-js lt-ie9" lang="en"> <![endif]-->
<!--[if gt IE 8]><!-->
<html class="no-js" lang="en">
  <!--<![endif]-->
  <head>
    <meta charset="utf-8">
    <title><%= $project_name %> - <%= title %></title>
    <meta name="author" content="<%= $meta->{author} %>" />
    <meta name="keywords" content="<%= $meta->{keywords} %>" />
    <meta name="description" content="<%= $meta->{description} %>" />
    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
    %= include 'layouts/head-load'
  </head>

  <body>
    %= include 'layouts/nav'
    %= include 'layouts/sponsors'
    %= include 'layouts/header'
    <%= content %>
    %= include 'layouts/body-load'
  </body>
</html>


@@ layouts/head-load.html.ep
    <!--

      Site design is stolen from William Dady's homepage.

      Visit http://williamdady.com/ and look around his beautiful site. :)

    -->

    <link rel="icon" href="./favicon.ico" type="image/x-icon" />
    <link rel="apple-touch-icon-precomposed" sizes="144x144" href="./img/apple-touch-icon-144x144-precomposed.png">
    <link rel="apple-touch-icon-precomposed" sizes="114x114" href="./img/apple-touch-icon-114x114-precomposed.png">
    <link rel="apple-touch-icon-precomposed" sizes="72x72" href="./img/apple-touch-icon-72x72-precomposed.png">
    <link rel="apple-touch-icon-precomposed" href="./img/apple-touch-icon-precomposed.png">

    <link rel="stylesheet" href="./jquery/css/ui-lightness/jquery-ui-1.8.24.custom.css">
    <link rel="stylesheet" href="./font-awesome/css/font-awesome.css">
    % for my $css (@$csses) {
      <link type="text/css" rel="stylesheet" href="./<%= $css %>"> 
    % }
    <script src="./js/modernizr.js"></script>


@@ layouts/body-load.html.ep
    <!-- Le javascript
    ================================================== -->
    <!-- Placed at the end of the document so the pages load faster -->

    <script src="//ajax.googleapis.com/ajax/libs/jquery/1.8.2/jquery.min.js"></script>
    <script src="//ajax.googleapis.com/ajax/libs/jqueryui/1.8.23/jquery-ui.min.js"></script>

    % for my $js (@$jses) {
      <script type="text/javascript" src="./js/<%= $js %>"></script>
    % }

    % if ($google_analytics) {
      <!-- google analytics -->
      <script type="text/javascript">
        var gaJsHost = (("https:" == document.location.protocol) ? "https://ssl." : "http://www.");
        document.write(unescape("%3Cscript src='" + gaJsHost + "google-analytics.com/ga.js' type='text/javascript'%3E%3C/script%3E"));
      </script>
      <script type="text/javascript">
        try {
          var pageTracker = _gat._getTracker("<%= $google_analytics %>");
          pageTracker._trackPageview();
        } catch(err) {}
      </script>
    % }


@@ layouts/header.html.ep
            <!-- nothing now -->
            <div id="forkme">
              <a href="https://github.com/seoulpm/KPW2012-Web">
                <img
                  style="z-index: 99; position: absolute; top: 0; left: 0; border: 0;"
                  src="https://s3.amazonaws.com/github/ribbons/forkme_left_red_aa0000.png"
                  alt="Fork me on GitHub">
              </a>
            </div>


@@ layouts/footer.html.ep
      <footer>
        <div class="social-links">
          <ul>
            <li>
              <a href="https://twitter.com/seoulpm" target="_blank">
                <img src="./img/twitter_button.png" alt="twitter button" />
              </a>
            </li>
            <li>
              <a href="http://www.facebook.com/groups/perl.kr/" target="_blank">
                <img src="./img/facebook_button.png" alt="facebook button" />
              </a>
            </li>
          </ul>
        </div>
        <div class="row">
          <div class="col_4 pre_1">
            <p class="copyright">
              &copy; <%= $copyright %>. All Rights Reserved.
            </p>
          </div>
          <div class="col_4 pre_1">
            <p class="builtby">
              Built by
                <a href="http://mojolicio.us/">Mojolicious</a> &amp;
                <a href="http://www.perl.org/">Perl</a>
            </p>
          </div>
        </div>
      </footer>


@@ layouts/nav.html.ep
    <nav id="main-nav">
      <ul>
        % for my $link (@$header_links) {
          <li class="<%= $link->{active} ? 'active' : q{} %>">
            <a href="<%= $link->{url} %>">
              <div class="label"><p><%= $link->{title} %></p></div>
              <i class="navicon <%= $link->{icon} %>"></i>
            </a>
          </li>
        % }
      </ul>
    </nav>


@@ layouts/sponsors.html.ep
    <div id="sponsors">
      <h2> Sponsors </h2>
      <ul>
        % for my $link (@$sponsors) {
          <li>
            <a href="<%= $link->{url} %>" alt="<%= $link->{title} %>">
              <div class="sponsor-image" id="<%= $link->{icon} %>"></div>
            </a>
          </li>
        % }
      </ul>
    </div>


@@ layouts/error.html.ep
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <title><%= $project_name %> - <%= title %></title>
    %= include 'layouts/head-load'
  </head>

  <body>
    %= include 'layouts/nav'

    <div id="content">
      <div class="container">
        <div class="row">

          <div class="span2">
            %= include 'layouts/header'
          </div> <!-- span2 -->

          <div class="span10">
            <div class="error-container">
              <%= content %>
            </div> <!-- error-container >
          </div> <!-- span10 -->

        </div> <!-- /row -->
      </div>
    </div> <!-- /content -->

    %= include 'layouts/footer'
    %= include 'layouts/body-load'
  </body>
</html>


@@ not_found.html.ep
% layout 'error', csses => [ 'error.css' ], jses => [];
% title '404 Not Found';
<h2>404 Not Found</h2>

<div class="error-details">
  Sorry, an error has occured, Requested page not found!
</div> <!-- /error-details -->


@@ layouts/login.html.ep
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <title><%= $project_name %> - <%= title %></title>
    %= include 'layouts/head-load'
  </head>

  <body>
    %= include 'layouts/nav'

    <div id="login-container">
      <%= content %>
    </div> <!-- login-container -->

    %= include 'layouts/footer'
    %= include 'layouts/body-load'

    <script type="text/javascript">
      $('#login-container input').first().focus();
    </script>

</script>
  </body>
</html>


@@ login.html.ep
% layout 'login', csses => [ 'login.css' ], jses => [];
% title 'Login';
<div id="login-header">
  <h3> <i class="icon-lock"></i> Login </h3>
</div> <!-- /login-header -->

<div id="login-content" class="clearfix">

  <form action="/" method="post">
    <fieldset>
      <div class="control-group">
        <label class="control-label" for="username">Username</label>
        <div class="controls"> <input type="text" class="" id="username" name="username"> </div>
      </div>
      <div class="control-group">
        <label class="control-label" for="password">Password</label>
        <div class="controls"> <input type="password" class="" id="password" name="password"> </div>
      </div>
    </fieldset>

    <div id="remember-me" class="pull-left">
      <input type="checkbox" name="remember" id="remember" />
      <label id="remember-label" for="remember">Remember Me</label>
    </div>

    <div class="pull-right">
      <button type="submit" class="btn btn-warning btn-large"> Login </button>
    </div>
  </form>

</div> <!-- /login-content -->

<div id="login-extra">
  <p>Fotgot Password? <a href="mailto:keedi.k@gmail.com">Contact Us.</a></p>
</div> <!-- /login-extra -->
