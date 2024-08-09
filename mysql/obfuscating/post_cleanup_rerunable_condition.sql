ALTER TABLE object_reference DROP COLUMN id;
DROP TABLE tmp_users;

DROP PROCEDURE IF EXISTS obfuscate_object_reference_batch;
DROP PROCEDURE IF EXISTS obfuscated_acl_role_batch;
DROP FUNCTION IF EXISTS should_obfuscate;
DROP FUNCTION IF EXISTS random_string;
DROP FUNCTION IF EXISTS translate;
DROP PROCEDURE IF EXISTS replace_obfuscated_batch;
DROP PROCEDURE IF EXISTS replace_obfuscated_user;
DROP PROCEDURE IF EXISTS obfuscate_object_reference_user_batch;
DROP PROCEDURE IF EXISTS obfuscate_object_revision_batch;
DROP PROCEDURE IF EXISTS obfuscated_task_batch;
DROP PROCEDURE IF EXISTS obfuscate_task_type;
DROP PROCEDURE IF EXISTS obfuscate_jira_doors;