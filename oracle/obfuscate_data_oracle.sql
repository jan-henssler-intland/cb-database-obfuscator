-- Audit trail logs
CREATE
OR
REPLACE PROCEDURE replace_obfuscate_users AS
BEGIN DECLARE
        obfuscate_audit_trial BOOLEAN DEFAULT FALSE;
v_name                VARCHAR2(50);
v_id                  NUMBER(10);
CURSOR c_users IS
SELECT id, name
FROM users;
l_start_time NUMBER;
l_end_time NUMBER;
l_elapsed_time NUMBER;
BEGIN l_start_time := DBMS_UTILITY.GET_TIME;

IF obfuscate_audit_trial
        THEN
            OPEN c_users;
LOOP
                FETCH c_users INTO v_id, v_name;
EXIT WHEN c_users%NOTFOUND;

-- "bond's personal wiki" -- "bond [1]" -- {"name":"bond","id":1} -- {"id":1,"name":"bond"}
UPDATE audit_trail_logs
SET details = REPLACE(
        REPLACE(
                REPLACE(
                        REPLACE(details, '{"id":' || v_id || ',"name":"' || v_name || '"}',
                                '{"id":' || v_id || ',"name":"user-' || v_id || '"}'),
                        '{"name":"' || v_name || '","id":' || v_id || '}',
                        '{"name":"user-' || v_id || '", "id":' || v_id || '}'),
                '"' || v_name || ' [' || v_id || ']"', '"user-' || v_id || ' [' || v_id || ']"'),
        '"' || v_name || '''s Personal Wiki"', '"user-' || v_id || '''s Personal Wiki"');
COMMIT;
END LOOP;
CLOSE c_users;
END IF;
l_end_time := DBMS_UTILITY.GET_TIME;
l_elapsed_time := l_end_time - l_start_time;
DBMS_OUTPUT.PUT_LINE('replace_obfuscate_object_revision elapsed time (milliseconds): ' || l_elapsed_time);
END;
END replace_obfuscate_users;
/

CREATE OR
REPLACE FUNCTION SHOULD_OBFUSCATE(
    field_value CLOB, label_id NUMBER)
    RETURN NUMBER IS
    l_start_time NUMBER;
l_end_time NUMBER;
l_elapsed_time NUMBER;
BEGIN l_start_time := DBMS_UTILITY.GET_TIME;

/*date 2019-08-20 22:00:00*/
IF
(NOT regexp_like(field_value,
    '^([1-2][0-9]{3})-([0-1][0-9])-([0-3][0-9])( [0-2][0-9]):([0-5][0-9]):([0-5][0-9])$', 'cn'))
/*Anything containing a whitespace and not a date should be obfuscated*/
AND
((regexp_like(field_value, '\s+', 'cn')) OR
    /*color #5eceeb*/
    ((NOT regexp_like(field_value, '^#([a-fA-F0-9]{6})$', 'cn')) AND
    /*Number 14*/
    (NOT regexp_like(field_value, '^[0-9]+$', 'cn')) AND
    /*boolean*/
    (NOT regexp_like(field_value, '^(true|false)$', 'cn')) AND
    /*one or more reference 9-1041#3152/1*/
    (NOT regexp_like(field_value, '^(([0-9]{1,2}-[0-9]{4,}#[0-9]{4,}(\/)[0-9]{1,},)?)+([0-9]{1,2}-[0-9]{4,}#[0-9]{4,}(\/)[0-9]{1,})$', 'cn')) AND
    /*one or more test case reference in test run 9-1793116/1#13306428/1*/
    (NOT regexp_like(field_value, '^(([0-9]{1,2}-[0-9]{4,}(\/)[0-9]{1,}#[0-9]{4,}(\/)[0-9]{1,},)?)+([0-9]{1,2}-[0-9]{4,}(\/)[0-9]{1,}#[0-9]{4,}(\/)[0-9]{1,})$', 'cn')) AND
    /*one or more issue or item [ITEM:1010#3331/1];[ITEM:1011#3332/1]*/
    (NOT regexp_like(field_value, '^((\[(ITEM|ISSUE):[0-9]{4,}#[0-9]{4,}\/[0-9]{1,}\];)?)+(\[(ITEM|ISSUE):[0-9]{4,}#[0-9]{4,}\/[0-9]{1,}\])$', 'cn')) AND
    /*Test run ID  label_id:1000104 value:2750e123c70a910cd6278a2c69f53676*/
    ((label_id < 1000000) OR
    MOD (label_id, 10) != 4 OR
    (NOT regexp_like(field_value, '^([0-9]|[a-f]){32}$', 'cn'))
    )))
THEN
        RETURN 1;
ELSE
        RETURN 0;
END IF;
l_end_time := DBMS_UTILITY.GET_TIME;
l_elapsed_time := l_end_time - l_start_time;
DBMS_OUTPUT.PUT_LINE('SHOULD_OBFUSCATE elapsed time (milliseconds): ' || l_elapsed_time);
END;
/

CREATE OR
REPLACE PROCEDURE replace_obfuscate_object_reference AS
BEGIN DECLARE
        obfuscate_object_reference BOOLEAN DEFAULT TRUE;
l_start_time NUMBER;
l_end_time NUMBER;
l_elapsed_time NUMBER;
BEGIN l_start_time := DBMS_UTILITY.GET_TIME;

IF obfuscate_object_reference
        THEN
-- object_reference obfuscate file links, mailto
UPDATE object_reference
SET url = 'file://' || from_id
WHERE url LIKE 'file://%';
UPDATE object_reference
SET url = 'mailto:' || from_id || '@testemail.testemail'
WHERE url LIKE 'mailto:%';
UPDATE object_reference
SET url = '/' || from_id
WHERE url LIKE '/%';
COMMIT;

-- obfuscate urls in wiki fields
UPDATE object_reference
SET url = 'url-something'
WHERE to_id IS NULL
  AND to_type_id IS NULL
  AND assoc_id IS NULL
  AND field_id IS NOT NULL;
COMMIT;

END IF;
l_end_time := DBMS_UTILITY.GET_TIME;
l_elapsed_time := l_end_time - l_start_time;
DBMS_OUTPUT.PUT_LINE('replace_obfuscate_object_reference elapsed time (milliseconds): ' || l_elapsed_time);
END;
END replace_obfuscate_object_reference;
/

-- batch wise object_revision table if it very large.
CREATE OR
REPLACE PROCEDURE replace_obfuscate_object_revision_batch(start_id INT, max_id INT) AS
BEGIN DECLARE
        obfuscate_object_revision BOOLEAN DEFAULT TRUE;

BEGIN IF obfuscate_object_revision
        THEN
/*update name of artifacts except: calendars, work calendars, roles, groups, member group,
  state transition, field definitions, choice option, release rank, review config,
  review tracker, state transition, transition condition, workflow action, artifact file link*/


UPDATE object_revision r
SET r.name = r.object_id || '-artifact ' || SUBSTR(r.name, 1, 4) || ' :' || LENGTH(r.name)
WHERE r.name NOT IN ('codeBeamer Review Project Review Tracker',
                     'codeBeamer Review Project Review Item Tracker',
                     'codeBeamer Review Project Review Config Template Tracker')
  AND r.type_id NOT IN (9, 10, 17, 18, 19, 21, 23, 25, 26, 33, 35, 44)
  AND r.object_id BETWEEN start_id AND max_id;
COMMIT;

-- update description of artifacts, except: calendar, work calendar, association,state transition, transition condition, workflow action
UPDATE object_revision r
SET r.description = JSON_MERGEPATCH(r.description,
                                    '{"description": "Obfuscated description' || dbms_random.string('a', 22) || '"}')
WHERE r.type_id NOT IN (9, 10, 17, 23, 24, 28)
  AND JSON_SERIALIZE(r.description) IS NOT NULL
  AND r.object_id BETWEEN start_id AND max_id;
COMMIT;

-- Update categoryName of project categories
UPDATE object_revision r
SET r.description = JSON_MERGEPATCH(r.description, '{"categoryName": "' || r.name || '"}')
WHERE r.type_id = 42
  AND JSON_SERIALIZE(r.description) IS NOT NULL
  AND r.object_id BETWEEN start_id AND max_id;
COMMIT;

-- delete simple comment message
UPDATE object_revision r
SET r.description = 'Obfuscated description-' || LENGTH(r.description)
WHERE r.type_id IN (13, 15)
  AND JSON_SERIALIZE(r.description) IS NULL
  AND r.object_id BETWEEN start_id AND max_id;
COMMIT;

-- delete description of : file, folder, baseline, user, tracker, dashboard
UPDATE object_revision r
SET r.description = NULL
WHERE r.type_id IN (1, 2, 12, 30, 31, 32, 34)
  AND r.object_id BETWEEN start_id AND max_id;
COMMIT;

END IF;
END;
END replace_obfuscate_object_revision_batch;
/

CREATE OR
REPLACE PROCEDURE replace_obfuscate_object_revision AS
BEGIN DECLARE
        l_start_index INTEGER := 1; -- Starting index for the loop
l_batch_size INTEGER := 5000; -- Batch size
max_id INTEGER;

l_start_time NUMBER;
l_end_time NUMBER;
l_elapsed_time NUMBER;
BEGIN l_start_time := DBMS_UTILITY.GET_TIME;

SELECT MAX(object_id)
INTO max_id
FROM object_revision;

WHILE l_start_index <= max_id LOOP
                replace_obfuscate_object_revision_batch(l_start_index, l_start_index + l_batch_size - 1);
COMMIT;
l_start_index := l_start_index + l_batch_size;
END LOOP;

l_end_time := DBMS_UTILITY.GET_TIME;
l_elapsed_time := l_end_time - l_start_time;
DBMS_OUTPUT.PUT_LINE('replace_obfuscate_object_revision elapsed time (milliseconds): ' || l_elapsed_time);
END;
END replace_obfuscate_object_revision;
/

CREATE OR
REPLACE PROCEDURE obfuscate_task_summary_details AS
BEGIN DECLARE
        obfuscate_task_summary_details BOOLEAN DEFAULT TRUE;
l_start_time NUMBER;
l_end_time NUMBER;
l_elapsed_time NUMBER;
BEGIN l_start_time := DBMS_UTILITY.GET_TIME;

IF obfuscate_task_summary_details
        THEN
-- update task summary and description
UPDATE task
SET summary = 'Task' || id || ' ' || SUBSTR(summary, 1, 4) || ' :' || LENGTH(summary)
WHERE summary IS NOT NULL;
COMMIT;

UPDATE task
SET details = TO_CHAR(LENGTH(details))
WHERE details IS NOT NULL;
COMMIT;
END IF;
l_end_time := DBMS_UTILITY.GET_TIME;
l_elapsed_time := l_end_time - l_start_time;
DBMS_OUTPUT.PUT_LINE('obfuscate_task_summary_details elapsed time (milliseconds): ' || l_elapsed_time);
END;
END obfuscate_task_summary_details;
/

CREATE OR
REPLACE PROCEDURE obfuscate_task_search_history AS
BEGIN DECLARE
        obfuscate_task_search_history BOOLEAN DEFAULT TRUE;
l_start_time NUMBER;
l_end_time NUMBER;
l_elapsed_time NUMBER;
BEGIN l_start_time := DBMS_UTILITY.GET_TIME;

IF obfuscate_task_search_history
        THEN
-- update task summary
UPDATE task_search_history
SET summary = 'Task' || id || ' ' || SUBSTR(summary, 1, 4) || ' :' || LENGTH(summary)
WHERE summary IS NOT NULL;
COMMIT;
END IF;
l_end_time := DBMS_UTILITY.GET_TIME;
l_elapsed_time := l_end_time - l_start_time;
DBMS_OUTPUT.PUT_LINE('obfuscate_task_search_history elapsed time (milliseconds): ' || l_elapsed_time);
END;
END obfuscate_task_search_history;
/

CREATE OR
REPLACE PROCEDURE obfuscate_task_field_value AS
BEGIN DECLARE
        obfuscate_task_field_value BOOLEAN DEFAULT TRUE;
l_start_time NUMBER;
l_end_time NUMBER;
l_elapsed_time NUMBER;
BEGIN l_start_time := DBMS_UTILITY.GET_TIME;

IF obfuscate_task_field_value
        THEN
-- UPDATE custom field value (not choice data)
UPDATE task_field_value
SET field_value = (
    CASE
        WHEN TRIM(TRANSLATE(SUBSTR(field_value, 1, 100), '0123456789-,.', ' ')) IS NULL
            THEN '1'
        ELSE TO_CHAR(SUBSTR(field_value, 1, 2) || ' :' || LENGTH(field_value))
        END)
WHERE field_value IS NOT NULL
  AND (label_id IN (3, 80) OR (label_id >= 1000 AND SHOULD_OBFUSCATE(field_value, label_id) = 1));
COMMIT;
END IF;
l_end_time := DBMS_UTILITY.GET_TIME;
l_elapsed_time := l_end_time - l_start_time;
DBMS_OUTPUT.PUT_LINE('obfuscate_task_field_value elapsed time (milliseconds): ' || l_elapsed_time);
END;
END obfuscate_task_field_value;
/

CREATE OR
REPLACE PROCEDURE obfuscate_task_field_history AS
BEGIN DECLARE
        obfuscate_task_field_history BOOLEAN DEFAULT TRUE;
l_start_time NUMBER;
l_end_time NUMBER;
l_elapsed_time NUMBER;
BEGIN l_start_time := DBMS_UTILITY.GET_TIME;

IF obfuscate_task_field_history
        THEN
-- UPDATE summary, description and custom field value
UPDATE task_field_history
SET old_value = (
    CASE
        WHEN old_value IS NOT NULL AND SHOULD_OBFUSCATE(old_value, label_id) = 1 THEN (
            CASE
                WHEN TRIM(TRANSLATE(SUBSTR(old_value, 1, 100), '0123456789-,.', ' ')) IS NULL
                    THEN TO_CHAR(revision - 1)
                ELSE TO_CHAR(SUBSTR(old_value, 1, 2) || ' :' || LENGTH(old_value))
                END)
        ELSE NULL END
    ),
    new_value = (
        CASE
            WHEN new_value IS NOT NULL AND SHOULD_OBFUSCATE(old_value, label_id) = 1 THEN (
                CASE
                    WHEN TRIM(TRANSLATE(SUBSTR(new_value, 1, 100), '0123456789-,.', ' ')) IS NULL
                        THEN TO_CHAR(revision)
                    ELSE TO_CHAR(SUBSTR(new_value, 1, 2) || ' :' || LENGTH(new_value))
                    END)
            ELSE NULL END
        )
WHERE label_id IN (3, 80)
   OR label_id >= 10000;
COMMIT;
END IF;
l_end_time := DBMS_UTILITY.GET_TIME;
l_elapsed_time := l_end_time - l_start_time;
DBMS_OUTPUT.PUT_LINE('obfuscate_task_field_history elapsed time (milliseconds): ' || l_elapsed_time);
END;
END obfuscate_task_field_history;
/

CREATE OR
REPLACE PROCEDURE obfuscate_task_type AS
BEGIN DECLARE
        obfuscate_task_type BOOLEAN DEFAULT TRUE;
l_start_time NUMBER;
l_end_time NUMBER;
l_elapsed_time NUMBER;
BEGIN l_start_time := DBMS_UTILITY.GET_TIME;

IF obfuscate_task_type
        THEN
-- TASK_TYPE reduce prefix to 2 characters
UPDATE task_type
SET prefix = SUBSTR(prefix, 1, 2);
COMMIT;
END IF;
l_end_time := DBMS_UTILITY.GET_TIME;
l_elapsed_time := l_end_time - l_start_time;
DBMS_OUTPUT.PUT_LINE('obfuscate_task_type elapsed time (milliseconds): ' || l_elapsed_time);
END;
END obfuscate_task_type;
/

CREATE OR
REPLACE FUNCTION extract_lob_data(lob_data IN CLOB) RETURN VARCHAR2 DETERMINISTIC
    IS
BEGIN RETURN DBMS_LOB.SUBSTR(lob_data, 100, 1);
END extract_lob_data;
/

-- create additional Index for performance improvements
CREATE INDEX obj_rev_name_type_idx ON object_revision (name, type_id);

-- finds faster null descriptions
CREATE INDEX obj_rev_desc_type_idx ON object_revision (extract_lob_data(DESCRIPTION), type_id);
CREATE INDEX obj_rev_type_idx ON object_revision (type_id);
CREATE INDEX obj_rev_id_type_idx ON object_revision (object_id, type_id);
CREATE INDEX task_summary_idx ON task (summary);
-- finds faster null descriptions
CREATE INDEX task_details_func_idx ON task (extract_lob_data(details) );
-- finds faster null descriptions
CREATE INDEX tfv_details_fidx ON task_field_value (label_id, extract_lob_data(field_value) );


-- obfuscate acl role
UPDATE acl_role
SET name        = id,
    description = NULL
WHERE name <> 'codeBeamer Review Project Review Role'
  AND name <> 'Project Admin'
  AND name <> 'Developer'
  AND name <> 'Stakeholder';
COMMIT;

CALL replace_obfuscate_object_reference();
COMMIT;

-- remove all file content except: vintage reports, calendar, work calendars
TRUNCATE TABLE object_revision_blobs;
COMMIT;

CALL replace_obfuscate_object_revision();
COMMIT;

-- update user data
UPDATE users
SET name               = 'user-' || id,
    passwd             = NULL,
    hostname           = NULL,
    firstname          = 'First-' || id,
    lastname           = 'Last-' || id,
    title              = NULL,
    address            = NULL,
    zip                = NULL,
    city               = NULL,
    state              = NULL,
    country            = NULL,
    language           = NULL,
    geo_country        = NULL,
    geo_region         = NULL,
    geo_city           = NULL,
    geo_latitude       = NULL,
    geo_longitude      = NULL,
    source_of_interest = NULL,
    scc                = NULL,
    team_size          = NULL,
    division_size      = NULL,
    company            = NULL,
    email              = 'user' || id || '@testemail.testemail',
    email_client       = NULL,
    phone              = NULL,
    mobil              = NULL,
    skills             = NULL,
    unused0            = NULL,
    unused1            = NULL,
    unused2            = NULL,
    referrer_url       = NULL
WHERE name NOT IN ('system', 'computed.update', 'deployment.executor', 'scm.executor');
COMMIT;

-- remove user photos
TRUNCATE TABLE users_small_photo_blobs;
COMMIT;
TRUNCATE TABLE users_large_photo_blobs;
COMMIT;

-- remove user preferences: DOORS_BRIDGE_LOGIN(63),JIRA_SERVER_LOGIN(67),SLACK_USER_ID(2001),SLACK_USER_TOKEN(2002)
DELETE
FROM user_pref
WHERE pref_id IN (63, 67, 2001, 2002);
COMMIT;

-- remove user keys
TRUNCATE TABLE user_key;
COMMIT;

-- rename projects
UPDATE existing
SET name     = 'Project' || proj_id,
    key_name = 'K-' || proj_id
WHERE name <> 'codeBeamer Review Project';
COMMIT;

-- remove jira synch
TRUNCATE TABLE object_job_schedule;
COMMIT;

-- update task summary and description
CALL obfuscate_task_summary_details();

-- update task summary
CALL obfuscate_task_search_history();

-- UPDATE custom field value (not choice data)
CALL obfuscate_task_field_value();

-- UPDATE summary, description and custom field value
CALL obfuscate_task_field_history();

-- TASK_TYPE reduce prefix to 2 characters
CALL obfuscate_task_type();

-- remove report jobs
TRUNCATE TABLE object_quartz_schedule;
COMMIT;

-- UPDATE tag name
UPDATE label
SET name = 'LABEL' || id
WHERE name NOT IN ('FINISHED_TESTRUN_GENERATION');
COMMIT;

UPDATE workingset
SET name        = 'WS-' || id,
    description = NULL
WHERE name != 'member';
COMMIT;

## TODO DISABLE CONSTRAINT FOR ALL TABLES WHICH SHOULD BE TRUNCATED

ALTER TABLE background_step DISABLE CONSTRAINT background_job_submitted_by_fk;
ALTER TABLE background_ job DISABLE CONSTRAINT background_job_submitted_by_fk;

TRUNCATE TABLE background_step;
COMMIT;

TRUNCATE TABLE background_job;
COMMIT;

TRUNCATE TABLE document_cache_data_blobs;
COMMIT;

TRUNCATE TABLE document_cache_data;
COMMIT;

TRUNCATE TABLE background_job_meta;
COMMIT;

TRUNCATE TABLE background_step_result;
COMMIT;

TRUNCATE TABLE background_step_context;
COMMIT;

TRUNCATE TABLE qrtz_blob_triggers;
COMMIT;

TRUNCATE TABLE qrtz_calendars;
COMMIT;

TRUNCATE TABLE qrtz_cron_triggers;
COMMIT;

TRUNCATE TABLE qrtz_fired_triggers;
COMMIT;

TRUNCATE TABLE qrtz_locks;
COMMIT;

TRUNCATE TABLE qrtz_paused_trigger_grps;
COMMIT;

TRUNCATE TABLE qrtz_scheduler_state;
COMMIT;

TRUNCATE TABLE qrtz_simple_triggers;
COMMIT;

TRUNCATE TABLE qrtz_simprop_triggers;
COMMIT;

-- remove stored configs
TRUNCATE TABLE application_configuration;
COMMIT;

ALTER TABLE background_ job ENABLE CONSTRAINT background_job_submitted_by_fk;
ALTER TABLE background_step ENABLE CONSTRAINT background_step_job_fk;

-- drop all indexes, procedures and function, these are not needed anymore after successful obfuscation
DROP INDEX obj_rev_name_type_idx;
DROP INDEX obj_rev_desc_type_idx;
DROP INDEX obj_rev_type_idx;
DROP INDEX obj_rev_id_type_idx;
DROP INDEX task_summary_idx;
DROP INDEX task_details_func_idx;
DROP INDEX tfv_details_fidx;

DROP FUNCTION SHOULD_OBFUSCATE;
DROP FUNCTION extract_lob_data;
DROP PROCEDURE obfuscate_task_type;
DROP PROCEDURE obfuscate_task_field_history;
DROP PROCEDURE obfuscate_task_field_value;
DROP PROCEDURE obfuscate_task_search_history;
DROP PROCEDURE obfuscate_task_summary_details;
DROP PROCEDURE replace_obfuscate_object_revision;
DROP PROCEDURE replace_obfuscate_object_revision_batch;
DROP PROCEDURE replace_obfuscate_object_reference;
DROP PROCEDURE replace_obfuscate_users;
