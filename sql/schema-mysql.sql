DROP TABLE IF EXISTS contact;
DROP TABLE IF EXISTS register;

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE contact (
    id          int(11)       NOT NULL AUTO_INCREMENT,
    email       varchar(128)  NOT NULL,
    subject     varchar(128)  NOT NULL,
    message     TEXT          NOT NULL,
    created_on  datetime      NOT NULL,

    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE register (
    id          int(11)       NOT NULL AUTO_INCREMENT,
    email       varchar(128)  NOT NULL,
    name        varchar(128)  NOT NULL,
    twitter     varchar(128)  DEFAULT NULL,
    nick        varchar(128)  DEFAULT NULL,
    message     TEXT          DEFAULT NULL,
    status      varchar(128)  DEFAULT NULL,
    waiting     varchar(128)  DEFAULT NULL,
    created_on  datetime      NOT NULL,
    updated_on  datetime      NOT NULL,

    PRIMARY KEY (id),
    UNIQUE  KEY (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
