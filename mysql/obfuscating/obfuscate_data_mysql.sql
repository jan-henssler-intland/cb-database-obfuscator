DELIMITER //
DROP PROCEDURE IF EXISTS replace_obfuscated_user;
CREATE PROCEDURE replace_obfuscated_user(start_id INT, max_id INT)
BEGIN
    DECLARE obfuscate_audit_trial BOOLEAN DEFAULT FALSE;

    DECLARE v_name VARCHAR(255);
    DECLARE v_id INT;
    DECLARE v_result INT DEFAULT 0;

    DECLARE c_user CURSOR FOR SELECT id, name FROM tmp_users;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_result = 1;

    IF obfuscate_audit_trial
    THEN

        OPEN c_user;

        replace_user:
        LOOP

            FETCH c_user
                INTO v_id, v_name;

            IF v_result = 1
            THEN
                LEAVE replace_user;
            END IF;

            CALL replace_obfuscated_batch(v_id, v_name, start_id, max_id);

        END LOOP replace_user;

        CLOSE c_user;
    END IF;
END //

DROP PROCEDURE IF EXISTS replace_obfuscated_batch;
CREATE PROCEDURE replace_obfuscated_batch(v_id INT, v_name VARCHAR(255), start_id INT, max_id INT)
BEGIN
    -- "bond's personal wiki" OR -- "bond [1]" OR -- {"name":"bond","id":1} OR -- {"id":1,"name":"bond"}
    ## Here noch was machen funktioniert nicht richtig.!!
    UPDATE audit_trail_logs
    SET details = REPLACE(REPLACE(REPLACE(REPLACE(details, CONCAT('{"id":', v_id, ',"name":"', v_name, '"}'),
                                                  CONCAT('{"id":', v_id, ',"name":user-"', v_id, '"}')),
                                          CONCAT('{"name":"', v_name, '","id":', v_id, '}'),
                                          CONCAT('{"name":user-"', v_id, '","id":', v_id, '}')),
                                  CONCAT('"', v_name, ' [', v_id, ']"'),
                                  CONCAT('"user-', v_id, ' [', v_id, ']"')),
                          CONCAT('"', v_name, '\'s Personal Wiki"'),
                          CONCAT('"user-', v_id, '\'s Personal Wiki"'))
    WHERE audit_trail_logs.id BETWEEN start_id AND max_id;
    COMMIT;

END //

DROP FUNCTION IF EXISTS translate//
CREATE FUNCTION translate(
    tar VARCHAR(255),
    ori VARCHAR(255),
    rpl VARCHAR(255)
)
    RETURNS VARCHAR(255) CHARSET utf8mb4
    DETERMINISTIC
BEGIN

    DECLARE i INT UNSIGNED DEFAULT 0;
    DECLARE cur_char CHAR(1);
    DECLARE ori_idx INT UNSIGNED;
    DECLARE result VARCHAR(255);

    SET result = '';

    WHILE i <= LENGTH(tar)
        DO
            SET cur_char = MID(tar, i, 1);
            SET ori_idx = INSTR(ori, cur_char);
            SET result = CONCAT(
                    result,
                    REPLACE(
                            cur_char,
                            MID(ori, ori_idx, 1),
                            MID(rpl, ori_idx, 1)
                        ));
            SET i = i + 1;
        END WHILE;
    RETURN result;
END //

DROP FUNCTION IF EXISTS random_string//
CREATE FUNCTION random_string(p_length BIGINT)
    RETURNS MEDIUMTEXT CHARSET utf8
    DETERMINISTIC
BEGIN
    SET @returnstr = '';
    SET @allowedchars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    SET @i = 0;

    WHILE (@i < p_length)
        DO
            SET @returnstr = CONCAT(@returnstr, SUBSTRING(@allowedchars, FLOOR(RAND() * LENGTH(@allowedchars) + 1), 1));
            SET @i = @i + 1;
        END WHILE;

    RETURN @returnstr;
END //

DROP FUNCTION IF EXISTS should_obfuscate//
CREATE FUNCTION should_obfuscate(
    field_value MEDIUMTEXT,
    label_id INT)
    RETURNS INT
    DETERMINISTIC
BEGIN
    -- date 2019-08-20 22:00:00
    IF (field_value RLIKE
        '^([1-2][0-9]{3})-([0-1][0-9])-([0-3][0-9])( [0-2][0-9]):([0-5][0-9]):([0-5][0-9])$') = 0 AND
        -- Anything containing a whitespace and not a date should be obfuscated
       ((field_value RLIKE '[[:blank:]]') OR
           -- color #5eceeb
        ((field_value RLIKE '^#([a-fA-F0-9]{6})$') = 0 AND
            -- Number 14
         (field_value RLIKE '^[0-9]+$') = 0 AND
            -- boolean
         (field_value RLIKE '^(true|false)$') = 0 AND
            -- one or more reference
         (field_value RLIKE
          '^(([0-9]{1,2}-[0-9]{4,}#[0-9]{4,}(\/)[0-9]{1,},)?)+([0-9]{1,2}-[0-9]{4,}#[0-9]{4,}(\/)[0-9]{1,})$') = 0 AND
            -- one or more issue or item
         (field_value RLIKE
          '^((\[(ITEM|ISSUE):[0-9]{4,}#[0-9]{4,}\/[0-9]{1,}\];)?)+(\[(ITEM|ISSUE):[0-9]{4,}#[0-9]{4,}\/[0-9]{1,}\])$') =
         0 AND
            -- Test run ID label_id:1000104 value:2750e123c70a910cd6278a2c69f53676
         ((label_id < 1000000) OR
          MOD(label_id, 10) != 4 OR
          (field_value RLIKE '^([0-9]|[a-f]){32}$') = 0
             ))) THEN
        RETURN 1;
    ELSE
        RETURN 0;
    END IF;
END//

-- obfuscate acl role
DROP PROCEDURE IF EXISTS obfuscated_acl_role_batch;
CREATE PROCEDURE obfuscated_acl_role_batch(start_id INT, max_id INT)
BEGIN
    UPDATE acl_role acl
    SET acl.name        = id,
        acl.description = NULL
    WHERE acl.name <> 'codeBeamer Review Project Review Role'
      AND acl.name <> 'Project Admin'
      AND acl.name <> 'Developer'
      AND acl.name <> 'Stakeholder'
      AND acl.id BETWEEN start_id AND max_id;
    COMMIT;
END //

DROP PROCEDURE IF EXISTS obfuscate_object_reference_batch;
CREATE PROCEDURE obfuscate_object_reference_batch(start_id INT, max_id INT)
BEGIN
    -- object_reference
    UPDATE object_reference obj_ref
    SET obj_ref.url = CONCAT('file://', obj_ref.from_id)
             WHERE obj_ref.url LIKE 'FILE://%' AND obj_ref.id BETWEEN start_id AND max_id;

            COMMIT;

            UPDATE object_reference obj_ref
            SET obj_ref.url = concat('mailto:', obj_ref.from_id, '@testemail.testemail')
            WHERE obj_ref.url LIKE 'mailto:%' AND obj_ref.id BETWEEN start_id AND max_id;

            COMMIT;

            UPDATE object_reference obj_ref
            SET obj_ref.url = concat('/', obj_ref.from_id)
            WHERE obj_ref.url LIKE '\/%' AND obj_ref.id BETWEEN start_id AND max_id;

            COMMIT;

            -- obfuscate urls in wiki fields
            UPDATE object_reference obj_ref
            SET obj_ref.url = 'url-something'
            WHERE obj_ref.to_id IS NULL
              AND obj_ref.to_type_id IS NULL
              AND obj_ref.assoc_id IS NULL
              AND obj_ref.field_id IS NOT NULL AND obj_ref.id BETWEEN start_id AND max_id;
            COMMIT;

            UPDATE object_reference obj_ref JOIN tmp_users u ON obj_ref.url LIKE u.name SET obj_ref.url = REGEXP_REPLACE(obj_ref.url, u.name,
                concat('USER-', u.id)) WHERE obj_ref.id BETWEEN start_id AND max_id;
            COMMIT;
END //

-- object_revision
DROP PROCEDURE IF EXISTS obfuscate_object_revision_batch;
    CREATE PROCEDURE obfuscate_object_revision_batch(start_id INT, max_id INT)
    BEGIN
        -- update name of artifacts except: calendars, work calendars, roles, groups, member group, state transition, field definitions, choice option, release rank, review config, review tracker, review config template tracker, artifact file link
        UPDATE object_revision r
        SET r.name = CONCAT(r.object_id, '-artifact ', SUBSTR(r.name, 1, 4), ' :', LENGTH(r.name))
        WHERE r.name NOT IN ('codeBeamer Review Project Review Tracker',
                             'codeBeamer Review Project Review Item Tracker',
                             'codeBeamer Review Project Review Config Template Tracker')
          AND r.type_id NOT IN (9, 10, 17, 18, 19, 21, 23, 25, 26, 33, 35, 44)
          AND r.object_id BETWEEN start_id AND max_id;
        COMMIT;

        -- update key, category of projects and trackers
        UPDATE object_revision r
        SET r.description = JSON_REPLACE(r.description,
                                         '$.keyName',
                                         CONCAT('K-', r.proj_id),
                                         '$.category',
                                         'TestCategory')
        WHERE r.type_id IN (22, 16)
          AND JSON_VALID(r.description)
          AND r.object_id BETWEEN start_id AND max_id;

        COMMIT;

        -- update description of artifacts, except: calendar, work calendar, association
        UPDATE object_revision r
        SET r.description = JSON_REPLACE(r.description, '$.description',
                                         CONCAT('Obfuscated description', random_string(22)))
        WHERE r.type_id NOT IN (9, 10, 17, 23, 24, 28)

          AND JSON_VALID(r.description)
          AND r.object_id BETWEEN start_id AND max_id;

        COMMIT;

        -- Update categoryName of project categories
        UPDATE object_revision r
        SET r.description = JSON_REPLACE(r.description, '$.categoryName', r.name)
        WHERE r.type_id = 42
          AND JSON_VALID(r.description)
          AND r.object_id BETWEEN start_id AND max_id;

        COMMIT;

        -- delete simple comment message
        UPDATE object_revision r
        SET r.description = CONCAT('Obfuscated description-', LENGTH(r.description))
        WHERE r.type_id IN (13, 15)
          AND NOT JSON_VALID(r.description)
          AND r.object_id BETWEEN start_id AND max_id;

        COMMIT;

        -- delete description of : file, folder, baseline, user, tracker, dashboard
        UPDATE object_revision r
        SET r.description = NULL
        WHERE r.type_id IN (1, 2, 12, 30, 31, 32, 34)
          AND r.object_id BETWEEN start_id AND max_id;

        COMMIT;
    END
    //

    DROP PROCEDURE IF EXISTS obfuscated_task_batch;
    CREATE PROCEDURE obfuscated_task_batch(start_id INT, max_id INT)
    BEGIN
        -- update task summary and description
        UPDATE task t
        SET t.summary = CONCAT('Task', t.id, ' ', SUBSTR(t.summary, 1, 4), ' :', LENGTH(t.summary))
        WHERE t.summary IS NOT NULL
          AND t.id BETWEEN start_id AND max_id;
        COMMIT;

        UPDATE task t
        SET t.details = CONVERT(LENGTH(t.details), CHAR)
        WHERE t.details IS NOT NULL
          AND t.id BETWEEN start_id AND max_id;
        COMMIT;

        -- UPDATE custom field value (not choice data)
        UPDATE task_field_value tfv
        SET tfv.field_value = (
            CASE
                WHEN TRIM(TRANSLATE(SUBSTR(tfv.field_value, 1, 100), '0123456789-,.', ' ')) IS NULL
                    THEN '1'
                ELSE CONCAT(SUBSTR(tfv.field_value, 1, 2), ' :', LENGTH(tfv.field_value))
                END)
        WHERE tfv.field_value IS NOT NULL
          AND should_obfuscate(tfv.field_value, tfv.label_id)
          AND (tfv.label_id IN (3, 80) OR tfv.label_id >= 1000)
          AND tfv.task_id BETWEEN start_id AND max_id;
        COMMIT;

        -- UPDATE summary, description and custom field value
        UPDATE task_field_history tfh
        SET tfh.old_value = (
            CASE
                WHEN tfh.old_value IS NOT NULL AND should_obfuscate(tfh.old_value, tfh.label_id) THEN (
                    CASE
                        WHEN TRIM(TRANSLATE(SUBSTR(old_value, 1, 100), '0123456789-,.', ' ')) IS NULL
                            THEN tfh.revision - 1
                        ELSE CONCAT(SUBSTR(old_value, 1, 2), ' :', LENGTH(tfh.old_value))
                        END)
                ELSE tfh.old_value END
            ),
            tfh.new_value = (
                CASE
                    WHEN tfh.new_value IS NOT NULL AND should_obfuscate(tfh.new_value, tfh.label_id)
                        THEN (
                        CASE
                            WHEN TRIM(TRANSLATE(SUBSTR(tfh.new_value, 1, 100), '0123456789-,.', ' ')) IS NULL
                                THEN tfh.revision
                            ELSE CONCAT(SUBSTR(tfh.new_value, 1, 2), ' :', LENGTH(tfh.new_value))
                            END)
                    ELSE new_value END
                )
        WHERE (tfh.label_id IN (3, 80)
            OR tfh.label_id >= 1000)
          AND tfh.task_id BETWEEN start_id AND max_id;
        COMMIT;

    END
    //




    DROP PROCEDURE IF EXISTS obfuscate_task_type;
    CREATE PROCEDURE obfuscate_task_type(start_id INT, max_id INT)
    BEGIN
        DECLARE obfuscate_task_type BOOLEAN DEFAULT TRUE;

        IF obfuscate_task_type
        THEN
            -- TASK_TYPE reduce prefix to 2 characters
            UPDATE task_type
            SET prefix = SUBSTR(prefix, 1, 2)
            WHERE id BETWEEN start_id AND max_id;
            COMMIT;
        END IF;
    END
    //

    DROP PROCEDURE IF EXISTS obfuscate_jira_doors;
    CREATE PROCEDURE obfuscate_jira_doors()
    BEGIN
        CREATE TABLE IF NOT EXISTS tmp_jira ENGINE=MEMORY AS (
            SELECT REF.assoc_id FROM object_reference REF
                                         INNER JOIN object TRK
                                                    ON TRK.id = REF.to_id
                                         INNER JOIN existing PRJ
                                                    ON PRJ.proj_id = TRK.proj_id
                                         INNER JOIN object_revision REV
                                                    ON REV.object_id = TRK.id
                                                        AND REV.revision = TRK.revision
                                         INNER JOIN object ASSOC
                                                    ON ASSOC.id = REF.assoc_id
                                         INNER JOIN object_revision ARV
                                                    ON ARV.object_id = ASSOC.id
                                                        AND ARV.revision = ASSOC.revision
            WHERE REF.from_type_id IN (2277294, 65231461)
              AND REF.to_type_id = 3
        );

        UPDATE object_revision SET description = '{"jobs":{}}' WHERE object_id IN ( SELECT assoc_id FROM tmp_jira );
        UPDATE object_revision SET description = '{"jobs":{}}' WHERE type_id = 17 AND description LIKE ('%{"jobs":{"%');
        COMMIT;
    END
    //

    DROP PROCEDURE IF EXISTS prepare_statement_queue;
    CREATE PROCEDURE prepare_statement_queue()
    BEGIN

        INSERT INTO statement_queue_obfuscate(statement, status, start_id, end_id) VALUE ('TRUNCATE TABLE object_revision_blobs;', 'Unfinished', 0, 0);
        INSERT INTO statement_queue_obfuscate(statement, status, start_id, end_id) VALUE ('UPDATE users SET name = CONCAT(''user-'', id), passwd = NULL, hostname = NULL, firstname = CONCAT(''First-'', id), lastname = CONCAT(''Last-'', id), title = NULL, address = NULL, zip = NULL, city = NULL, state = NULL,country = NULL, language = NULL, geo_country = NULL, geo_region = NULL, geo_city = NULL, geo_latitude = NULL, geo_longitude= NULL, source_of_interest = NULL, scc= NULL, team_size= NULL, division_size= NULL, company= NULL, email= CONCAT(''user'', id, ''@testemail.testemail''), email_client = NULL, phone= NULL, mobil= NULL, skills = NULL, unused0= NULL, unused1 = NULL, unused2 = NULL, referrer_url = NULL WHERE name NOT IN (''system'', ''computed.update'', ''deployment.executor'', ''scm.executor'');',
                                                                                          'Unfinished', 0, 0);
        INSERT INTO statement_queue_obfuscate(statement, status, start_id, end_id) VALUE ('TRUNCATE TABLE users_small_photo_blobs;', 'Unfinished', 0, 0);
        INSERT INTO statement_queue_obfuscate(statement, status, start_id, end_id) VALUE ('TRUNCATE TABLE users_large_photo_blobs;', 'Unfinished', 0, 0);

        INSERT INTO statement_queue_obfuscate(statement, status, start_id, end_id) VALUE ('DELETE FROM user_pref WHERE pref_id IN (63, 67, 2001, 2002);',
                                                                                          'Unfinished', 0, 0);
        INSERT INTO statement_queue_obfuscate(statement, status, start_id, end_id) VALUE ('TRUNCATE TABLE user_key;', 'Unfinished', 0, 0);
        INSERT INTO statement_queue_obfuscate(statement, status, start_id, end_id) VALUE ('UPDATE existing SET name = CONCAT(''Project'', proj_id), key_name = CONCAT(''K-'', proj_id) WHERE name <> ''codeBeamer Review Project'';',
                                                                                          'Unfinished', 0, 0);
        INSERT INTO statement_queue_obfuscate(statement, status, start_id, end_id) VALUE ('TRUNCATE TABLE object_job_schedule;', 'Unfinished', 0, 0);
        INSERT INTO statement_queue_obfuscate(statement, status, start_id, end_id) VALUE ('TRUNCATE TABLE object_quartz_schedule;', 'Unfinished', 0, 0);
        INSERT INTO statement_queue_obfuscate(statement, status, start_id, end_id) VALUE ('UPDATE label SET name = CONCAT(''LABEL'', id) WHERE name NOT IN (''FINISHED_TESTRUN_GENERATION'');',
                                                                                          'Unfinished', 0, 0);

        INSERT INTO statement_queue_obfuscate(statement, status, start_id, end_id) VALUE ('UPDATE workingset SET name = CONCAT(''WS-'', id), description = NULL WHERE name != ''member'';',
                                                                                          'Unfinished', 0, 0);
        INSERT INTO statement_queue_obfuscate(statement, status, start_id, end_id) VALUE ('SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE background_job;
SET FOREIGN_KEY_CHECKS = 1;', 'Unfinished', 0, 0);
        INSERT INTO statement_queue_obfuscate(statement, status, start_id, end_id) VALUE ('SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE background_step;
SET FOREIGN_KEY_CHECKS = 1;', 'Unfinished', 0, 0);
        INSERT INTO statement_queue_obfuscate(statement, status, start_id, end_id) VALUE ('SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE document_cache_data_blobs;
SET FOREIGN_KEY_CHECKS = 1;', 'Unfinished', 0, 0);
        INSERT INTO statement_queue_obfuscate(statement, status, start_id, end_id) VALUE ('SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE document_cache_data;
SET FOREIGN_KEY_CHECKS = 1;', 'Unfinished', 0, 0);

        INSERT INTO statement_queue_obfuscate(statement, status, start_id, end_id) VALUE ('TRUNCATE TABLE background_job_meta;', 'Unfinished', 0, 0);
        INSERT INTO statement_queue_obfuscate(statement, status, start_id, end_id) VALUE ('TRUNCATE TABLE background_step_result;', 'Unfinished', 0, 0);

        INSERT INTO statement_queue_obfuscate(statement, status, start_id, end_id) VALUE ('TRUNCATE TABLE background_step_context;', 'Unfinished', 0, 0);
        INSERT INTO statement_queue_obfuscate(statement, status, start_id, end_id) VALUE ('TRUNCATE TABLE QRTZ_BLOB_TRIGGERS;', 'Unfinished', 0, 0);
        INSERT INTO statement_queue_obfuscate(statement, status, start_id, end_id) VALUE ('TRUNCATE TABLE QRTZ_CALENDARS;', 'Unfinished', 0, 0);
        INSERT INTO statement_queue_obfuscate(statement, status, start_id, end_id) VALUE ('TRUNCATE TABLE QRTZ_CRON_TRIGGERS;', 'Unfinished', 0, 0);
        INSERT INTO statement_queue_obfuscate(statement, status, start_id, end_id) VALUE ('TRUNCATE TABLE QRTZ_FIRED_TRIGGERS;', 'Unfinished', 0, 0);
        INSERT INTO statement_queue_obfuscate(statement, status, start_id, end_id) VALUE ('TRUNCATE TABLE QRTZ_LOCKS;', 'Unfinished', 0, 0);
        INSERT INTO statement_queue_obfuscate(statement, status, start_id, end_id) VALUE ('TRUNCATE TABLE QRTZ_PAUSED_TRIGGER_GRPS;', 'Unfinished', 0, 0);
        INSERT INTO statement_queue_obfuscate(statement, status, start_id, end_id) VALUE ('TRUNCATE TABLE QRTZ_SCHEDULER_STATE;', 'Unfinished', 0, 0);
        INSERT INTO statement_queue_obfuscate(statement, status, start_id, end_id) VALUE ('TRUNCATE TABLE QRTZ_SIMPLE_TRIGGERS;', 'Unfinished', 0, 0);
        INSERT INTO statement_queue_obfuscate(statement, status, start_id, end_id) VALUE ('TRUNCATE TABLE QRTZ_SIMPROP_TRIGGERS;', 'Unfinished', 0, 0);
    END
    //
DELIMITER ;
CALL prepare_statement_queue();
