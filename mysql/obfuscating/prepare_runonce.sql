alter table object_reference add id int PRIMARY KEY AUTO_INCREMENT;
#copy users table because obfuscating will destroy it
DROP TABLE IF EXISTS tmp_users;
CREATE TABLE tmp_users like users;
INSERT INTO tmp_users select * from users;
SET AUTOCOMMIT = 0;

DROP TABLE IF EXISTS statement_queue_obfuscate;
CREATE TABLE statement_queue_obfuscate (id int PRIMARY KEY AUTO_INCREMENT, statement MEDIUMTEXT, status VARCHAR(255), start_id INT, end_id INT);

DROP TABLE IF EXISTS statement_finished_obfuscate;
CREATE TABLE statement_finished_obfuscate (id int, statement MEDIUMTEXT, status VARCHAR(255), start_id INT, end_id INT);
