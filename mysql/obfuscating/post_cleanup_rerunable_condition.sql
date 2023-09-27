alter table object_reference drop column id;
drop TABLE tmp_users;

DROP FUNCTION IF EXISTS translate//
DROP FUNCTION IF EXISTS random_string//
DROP FUNCTION IF EXISTS should_obfuscate//
DROP PROCEDURE replace_obfuscated_user//
DROP PROCEDURE replace_obfuscated_batch//
DROP PROCEDURE obfuscated_acl_role_batch//
DROP PROCEDURE obfuscated_task_batch//
DROP PROCEDURE run_obfuscated//