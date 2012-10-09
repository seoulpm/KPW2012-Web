KPW2012-Web
===========

Korean Perl Workshop 2012

## setup ##

    $ git clone git@github.com:seoulpm/KPW2012-Web.git    # read/write
    $ cd KPW2012-Web/
    $ cpanm --installdeps .
    $ cp db.conf.sample db.conf
    $ mysql -u root -p
    mysql> CREATE DATABASE IF NOT EXISTS `kpw2012`;
    mysql> GRANT ALL PRIVILEGES ON `kpw2012`.* TO <username>@localhost IDENTIFIED by "<password>";
    mysql> exit
    $ mysql -u <username> -p kpw2012 < sql/schema-mysql.sql
    # edit db configuration `kpw2012-web.conf`
    $ ./run    # develoment
    $ ./deploy # deployment


    $ start_server --pid-file=kpw2012.pid --status-file=kpw2012.status --restart    # graceful restart
    $ kill `cat kpw2012.pid`    # kill service
