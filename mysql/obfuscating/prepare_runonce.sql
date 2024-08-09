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

CREATE INDEX object_reference_url_idx ON object_reference (url(10));
CREATE INDEX task_summary_idx ON task(summary);
CREATE INDEX task_field_new_value_idx ON task_field_history(new_value(10));
CREATE INDEX task_field_old_value_idx ON task_field_history(old_value(10));
CREATE INDEX task_field_value_field_value ON task_field_value(field_value(10));
CREATE FULLTEXT INDEX object_reference_url_ft_idx ON object_reference(url);