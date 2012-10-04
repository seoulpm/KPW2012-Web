DROP TABLE IF EXISTS contact;

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
