DELIMITER //
DROP PROCEDURE IF EXISTS replace_obfuscated_user;
//
CREATE PROCEDURE replace_obfuscated_user()
BEGIN
    DECLARE obfuscate_audit_trial BOOLEAN DEFAULT FALSE;

    DECLARE v_name VARCHAR(255);
    DECLARE v_id INT;
    DECLARE v_result INT DEFAULT 0;

    DECLARE c_user CURSOR FOR SELECT id, name FROM users;
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

            -- "bond's personal wiki" OR -- "bond [1]" OR -- {"name":"bond","id":1} OR -- {"id":1,"name":"bond"}
            UPDATE audit_trail_logs
            SET details = replace(replace(replace(replace(details, concat('{"id":', v_id, ',"name":"', v_name, '"}'),
                                  concat('{"id":', v_id, ',"name":user-"', v_id, '"}')), concat('{"name":"', v_name, '","id":', v_id, '}'),
                                  concat('{"name":user-"', v_id, '","id":', v_id, '}')), concat('"', v_name, ' [', v_id, ']"'),
                                  concat('"user-', v_id, ' [', v_id, ']"')), concat('"', v_name, '\'s Personal Wiki"'),
                                  concat('"user-', v_id, '\'s Personal Wiki"'));

        END LOOP replace_user;

        CLOSE c_user;
    END IF;
END;
//
DROP FUNCTION IF EXISTS translate//
CREATE FUNCTION translate(
    tar VARCHAR(255),
    ori VARCHAR(255),
    rpl VARCHAR(255)
)
    RETURNS VARCHAR(255) CHARSET utf8mb4 DETERMINISTIC
BEGIN

    DECLARE i INT UNSIGNED DEFAULT 0;
    DECLARE cur_char CHAR(1);
    DECLARE ori_idx INT UNSIGNED;
    DECLARE result VARCHAR(255);

    SET result = '';

    WHILE i <= length(tar)
        DO
            SET cur_char = mid(tar, i, 1);
            SET ori_idx = INSTR(ori, cur_char);
            SET result = concat(
                    result,
                    REPLACE(
                            cur_char,
                            mid(ori, ori_idx, 1),
                            mid(rpl, ori_idx, 1)
                        ));
            SET i = i + 1;
        END WHILE;
    RETURN result;
END
//
DROP FUNCTION IF EXISTS random_string//
CREATE FUNCTION random_string(p_length BIGINT)
    RETURNS MEDIUMTEXT CHARSET utf8 DETERMINISTIC
BEGIN
    SET @returnstr = '';
    SET @allowedchars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    SET @i = 0;

    WHILE (@i < p_length)
        DO
            SET @returnstr = CONCAT(@returnstr, substring(@allowedchars, FLOOR(RAND() * LENGTH(@allowedchars) + 1), 1));
            SET @i = @i + 1;
        END WHILE;

    RETURN @returnstr;
END
//
DROP FUNCTION IF EXISTS should_obfuscate//
CREATE FUNCTION should_obfuscate(
    field_value MEDIUMTEXT,
    label_id INT)
    RETURNS INT
    DETERMINISTIC
BEGIN
    /*date 2019-08-20 22:00:00*/
    IF (field_value RLIKE
        '^([1-2][0-9]{3})-([0-1][0-9])-([0-3][0-9])( [0-2][0-9]):([0-5][0-9]):([0-5][0-9])$') = 0 AND
        /*Anything containing a whitespace and not a date should be obfuscated*/
       ((field_value RLIKE '[[:blank:]]') OR
           /*color #5eceeb*/
        ((field_value RLIKE '^#([a-fA-F0-9]{6})$') = 0 AND
            /*Number 14*/
         (field_value RLIKE '^[0-9]+$') = 0 AND
            /*boolean*/
         (field_value RLIKE '^(true|false)$') = 0 AND
            /*one or more reference*/
         (field_value RLIKE
          '^(([0-9]{1,2}-[0-9]{4,}#[0-9]{4,}(\/)[0-9]{1,},)?)+([0-9]{1,2}-[0-9]{4,}#[0-9]{4,}(\/)[0-9]{1,})$') = 0 AND
            /*one or more issue or item*/
         (field_value RLIKE
          '^((\[(ITEM|ISSUE):[0-9]{4,}#[0-9]{4,}\/[0-9]{1,}\];)?)+(\[(ITEM|ISSUE):[0-9]{4,}#[0-9]{4,}\/[0-9]{1,}\])$') =
         0 AND
            /*Test run ID label_id:1000104 value:2750e123c70a910cd6278a2c69f53676*/
         ((label_id < 1000000) OR
          MOD(label_id, 10) != 4 OR
          (field_value RLIKE '^([0-9]|[a-f]){32}$') = 0
             ))) THEN
        return 1;
    ELSE
        return 0;
    END IF;
END//

DROP PROCEDURE IF EXISTS obfuscate_object_reference;
//
CREATE PROCEDURE obfuscate_object_reference()
BEGIN
    DECLARE obfuscate_object_reference BOOLEAN DEFAULT TRUE;
    IF obfuscate_object_reference
    THEN
        /*object_reference*/
		UPDATE object_reference
		SET url = concat('file://', from_id)
		WHERE url LIKE 'file://%';
		UPDATE object_reference
		SET url = concat('mailto:', from_id, '@testemail.testemail')
		WHERE url LIKE 'mailto:%';
		UPDATE object_reference
		SET url = concat('/', from_id)
		WHERE url LIKE '\/%';

		/*obfuscate urls in wiki fields*/
		UPDATE object_reference
		SET url = 'url-something'
		WHERE to_id IS NULL
		AND to_type_id IS NULL
		AND assoc_id IS NULL
		AND field_id IS NOT NULL;

		/*obfuscate usernames in url*/
		UPDATE object_reference ref
		inner join users u
		on lower(ref.url)
		like u.name
		set url=replace(url, u.name, concat('user-', u.id));

    END IF;
END;
//

DROP PROCEDURE IF EXISTS obfuscate_object_revision;
//
CREATE PROCEDURE obfuscate_object_revision()
BEGIN
    DECLARE obfuscate_object_revision BOOLEAN DEFAULT TRUE;
    IF obfuscate_object_revision
    THEN
        /*update name of artifacts except: calendars, work calendars, roles, groups, member group, state transition, field definitions, choice option, release rank, review config, review tracker, review config template tracker, artifact file link*/
		UPDATE object_revision r
		SET r.name = concat(r.object_id, '-artifact ', substr(r.name, 1, 4), ' :', LENGTH(r.name))
		WHERE r.name NOT IN ('codeBeamer Review Project Review Tracker',
							 'codeBeamer Review Project Review Item Tracker',
							 'codeBeamer Review Project Review Config Template Tracker')
		  AND r.type_id NOT IN (9, 10, 17, 18, 19, 21, 23, 25, 26, 33, 35, 44);

		COMMIT;

		/*update description of artifacts, except: calendar, work calendar, association*/
		UPDATE object_revision r
		SET r.description = JSON_REPLACE(r.description,
										 '$.description',
										 concat('Obfuscated description-',
												LENGTH(r.description)))
		WHERE r.type_id NOT IN (9, 10, 17, 23, 24, 28)
		  AND JSON_VALID(r.description);
		COMMIT;

		/*update key, category of projects and trackers*/
		UPDATE object_revision r
		SET r.description = JSON_REPLACE(r.description,
										 '$.keyName',
										 concat('K-', r.proj_id),
										 '$.category',
										 'TestCategory')
		WHERE r.type_id IN (22, 16)
		  AND JSON_VALID(r.description);
		COMMIT;

		/*Update categoryName of project categories*/
		UPDATE object_revision r
		SET r.description = JSON_REPLACE(r.description, '$.categoryName', r.name)
		WHERE r.type_id = 42
		  AND JSON_VALID(r.description);
		COMMIT;

		/*delete simple comment message*/
		UPDATE object_revision r
		SET r.description = CONCAT('Obfuscated description-', LENGTH(r.description))
		WHERE r.type_id IN (13, 15)
		  AND NOT JSON_VALID(r.description);
		COMMIT;

		/*delete description of : file, folder, baseline, user, tracker, dashboard*/
		UPDATE object_revision r
		SET r.description = NULL
		WHERE r.type_id IN (1, 2, 12, 30, 31, 32, 34);
		COMMIT;

    END IF;
END;
//

DROP PROCEDURE IF EXISTS obfuscate_task_summary_details;
//
CREATE PROCEDURE obfuscate_task_summary_details()
BEGIN
    DECLARE obfuscate_task_summary_details BOOLEAN DEFAULT TRUE;
    IF obfuscate_task_summary_details
    THEN
		/*update task summary and description*/
		UPDATE task
		SET summary = concat('Task', id, ' ', substr(summary, 1, 4), ' :', LENGTH(summary))
		WHERE summary IS NOT NULL;
		COMMIT;

		UPDATE task
		SET details = CONVERT(LENGTH(details), CHAR)
		WHERE details IS NOT NULL;
		COMMIT;
	END IF;
END;
//

DROP PROCEDURE IF EXISTS obfuscate_task_search_history;
//
CREATE PROCEDURE obfuscate_task_search_history()
BEGIN
    DECLARE obfuscate_task_search_history BOOLEAN DEFAULT TRUE;
    IF obfuscate_task_search_history
    THEN
		/*update task summary*/
		UPDATE task_search_history
		SET summary = concat('Task', id, ' ', substr(summary, 1, 4), ' :', LENGTH(summary))
		WHERE summary IS NOT NULL;
		COMMIT;
	END IF;
END;
//

DROP PROCEDURE IF EXISTS obfuscate_task_field_value;
//
CREATE PROCEDURE obfuscate_task_field_value()
BEGIN
    DECLARE obfuscate_task_field_value BOOLEAN DEFAULT TRUE;
    IF obfuscate_task_field_value
    THEN
		/*UPDATE custom field value (not choice data)*/
		UPDATE task_field_value
		SET field_value = (
			CASE
				WHEN TRIM(TRANSLATE(substr(field_value, 1, 100), '0123456789-,.', ' ')) IS NULL
					THEN '1'
				ELSE concat(substr(field_value, 1, 2), ' :', LENGTH(field_value))
				END)
		WHERE field_value IS NOT NULL
		  AND should_obfuscate(field_value, label_id)
		  AND (label_id in (3, 80) OR label_id >= 1000);
		COMMIT;
	END IF;
END;
//

DROP PROCEDURE IF EXISTS obfuscate_task_field_history;
//
CREATE PROCEDURE obfuscate_task_field_history()
BEGIN
    DECLARE obfuscate_task_field_history BOOLEAN DEFAULT TRUE;
    IF obfuscate_task_field_history
    THEN
		/*UPDATE summary, description and custom field value*/
		UPDATE task_field_history
		SET old_value = (
			CASE
				WHEN old_value IS NOT NULL AND should_obfuscate(old_value, label_id) THEN (
					CASE
						WHEN TRIM(TRANSLATE(substr(old_value, 1, 100), '0123456789-,.', ' ')) IS NULL
							THEN revision - 1
						ELSE concat(substr(old_value, 1, 2), ' :', LENGTH(old_value))
						END)
				ELSE old_value END
			),
			new_value = (
				CASE
					WHEN new_value IS NOT NULL and should_obfuscate(new_value, label_id) THEN (
						CASE
							WHEN TRIM(TRANSLATE(substr(new_value, 1, 100), '0123456789-,.', ' ')) IS NULL
								THEN revision
							ELSE concat(substr(new_value, 1, 2), ' :', LENGTH(new_value))
							END)
					ELSE new_value END
				)
		WHERE label_id IN (3, 80)
		   OR (label_id >= 1000);
		COMMIT;
	END IF;
END;
//

DROP PROCEDURE IF EXISTS obfuscate_task_type;
//
CREATE PROCEDURE obfuscate_task_type()
BEGIN
    DECLARE obfuscate_task_type BOOLEAN DEFAULT TRUE;
    IF obfuscate_task_type
    THEN
		/*TASK_TYPE reduce prefix to 2 characters*/
		UPDATE task_type
		SET prefix = substr(prefix, 1, 2);
		COMMIT;
	END IF;
END;
//

DELIMITER ;

SET AUTOCOMMIT = 0;

/*obfuscate acl role*/
UPDATE acl_role
SET name        = id,
    description = NULL
WHERE name <> 'codeBeamer Review Project Review Role'
  AND name <> 'Project Admin'
  AND name <> 'Developer'
  AND name <> 'Stakeholder';

CALL obfuscate_object_reference();
COMMIT;

/*in mysql it's not supported*/
truncate table object_revision_blobs;
COMMIT;

CALL obfuscate_object_revision();
COMMIT;

/*Clear the JIRA or DOORs history entry*/
CREATE TEMPORARY TABLE IF NOT EXISTS tmp_jira ENGINE=MEMORY AS (
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

UPDATE object_revision SET description = NULL WHERE object_id IN ( SELECT assoc_id FROM tmp_jira );
COMMIT;

CALL replace_obfuscated_user();

/*update user data*/
UPDATE users
SET name               = concat('user-', id),
    passwd             = NULL,
    hostname           = NULL,
    firstname          = concat('First-', id),
    lastname           = concat('Last-', id),
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
    email              = concat('user', id, '@testemail.testemail'),
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

/*remove user photos*/
TRUNCATE TABLE users_small_photo_blobs;
COMMIT;

TRUNCATE TABLE users_large_photo_blobs;
COMMIT;

/*remove user preferences: DOORS_BRIDGE_LOGIN(63),JIRA_SERVER_LOGIN(67),SLACK_USER_ID(2001),SLACK_USER_TOKEN(2002)*/
DELETE
FROM user_pref
WHERE pref_id IN (63, 67, 2001, 2002);
COMMIT;

/*remove user keys*/
TRUNCATE TABLE user_key;
COMMIT;

/*rename projects*/
UPDATE existing
SET name     = concat('Project', proj_id),
    key_name = concat('K-', proj_id)
WHERE name <> 'codeBeamer Review Project';
COMMIT;

/*remove jira synch*/
TRUNCATE TABLE object_job_schedule;
COMMIT;

/*update task summary and description*/
CALL obfuscate_task_summary_details();

/*update task summary*/
CALL obfuscate_task_search_history();

/*UPDATE custom field value (not choice data)*/
CALL obfuscate_task_field_value();

/*UPDATE summary, description and custom field value*/
CALL obfuscate_task_field_history();

/*TASK_TYPE reduce prefix to 2 characters*/
CALL obfuscate_task_type();

/*remove report jobs*/
TRUNCATE TABLE object_quartz_schedule;
COMMIT;

/*UPDATE tag name*/
UPDATE label
SET name = concat('LABEL', id)
WHERE name NOT IN ('FINISHED_TESTRUN_GENERATION');
COMMIT;

UPDATE workingset
SET name        = concat('WS-', id),
    description = NULL
WHERE name != 'member';
COMMIT;

SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE table background_job;
SET FOREIGN_KEY_CHECKS = 1;
COMMIT;

SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE table background_step;
SET FOREIGN_KEY_CHECKS = 1;
COMMIT;

TRUNCATE TABLE document_cache_data_blobs;
COMMIT;

SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE table document_cache_data;
SET FOREIGN_KEY_CHECKS = 1;
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

/*remove stored configs*/
TRUNCATE TABLE application_configuration;
COMMIT;

DELIMITER //
DROP FUNCTION IF EXISTS translate//
DROP FUNCTION IF EXISTS random_string//
DROP FUNCTION IF EXISTS should_obfuscate//
DROP PROCEDURE replace_obfuscated_user//
DELIMITER ;