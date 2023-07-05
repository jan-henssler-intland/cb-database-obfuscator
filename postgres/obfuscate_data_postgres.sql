/*audit_trail*/
DO $$
<<audit_trail>>
	DECLARE obfuscate_audit_trial BOOLEAN DEFAULT FALSE;
	DECLARE v_name VARCHAR(50);
	DECLARE v_id INTEGER;
	DECLARE c_user CURSOR FOR SELECT id, name FROM users;

BEGIN
IF obfuscate_audit_trial THEN

	OPEN c_user;

	LOOP
		FETCH c_user INTO v_id, v_name;
		EXIT WHEN NOT found;

		-- "bond's personal wiki"
		UPDATE audit_trail_logs SET details=replace(details, CONCAT('"', v_name, '''s Personal Wiki"'), CONCAT('"user-', v_id, '''s Personal Wiki"'));

		-- "bond [1]"
		UPDATE audit_trail_logs SET details=replace(details, CONCAT('"', v_name, ' [', v_id, ']"'), CONCAT('"user-', v_id, ' [', v_id, ']"'));

		-- {"name":"bond","id":1}
		UPDATE audit_trail_logs SET details=replace(details, CONCAT('{"name":"', v_name, '","id":', v_id, '}'), CONCAT('{"name":user-"', v_id, '","id":', v_id, '}'));

		-- {"id":1,"name":"bond"}
		UPDATE audit_trail_logs SET details=replace(details, CONCAT('{"id":', v_id, ',"name":"', v_name, '"}'), CONCAT('{"id":', v_id, ',"name":user-"', v_id, '"}'));

	END LOOP;
	CLOSE c_user;
END IF;
END audit_trail $$;

CREATE OR REPLACE FUNCTION RANDOM_STRING(p_LENGTH BIGINT)
	RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
	v_random_string TEXT;
BEGIN
  SELECT STRING_AGG (SUBSTR('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789', CEIL(RANDOM() * 62)::INTEGER, 1), '')
  INTO v_random_string
  FROM   GENERATE_SERIES(1, p_LENGTH);
  RETURN v_random_string;
END;
$$;

CREATE OR REPLACE FUNCTION IS_VALID_JSON(p_json TEXT)
	RETURNS BOOLEAN
LANGUAGE plpgsql
AS
$$
BEGIN
	RETURN (p_json :: JSON IS NOT NULL);
	EXCEPTION
	WHEN OTHERS
		THEN
			RETURN FALSE;
END;
$$;

CREATE OR REPLACE FUNCTION SHOULD_OBFUSCATE(field_value TEXT, label_id INTEGER)
    RETURNS BOOLEAN
    LANGUAGE plpgsql
AS
$$
BEGIN
    RETURN /*date 2019-08-20 22:00:00*/
                field_value !~
                '^([1-2][0-9]{3})-([0-1][0-9])-([0-3][0-9])(?:( [0-2][0-9]):([0-5][0-9]):([0-5][0-9]))$' AND
                (field_value ~ '\s+' OR
                    /*color #5eceeb*/
                 (field_value !~ '^#([a-fA-F0-9]{6})$' AND
                     /*Number 14*/
                  field_value !~ '^[0-9]+$' AND
                     /*boolean*/
                  field_value !~ '^(true|false)$' AND
                     /*one or more reference 9-1041#3152/1*/
                  field_value !~
                  '^(([0-9]{1,2}-[0-9]{4,}#[0-9]{4,}(\/)[0-9]{1,},)?)+([0-9]{1,2}-[0-9]{4,}#[0-9]{4,}(\/)[0-9]{1,})$' AND
                    /*one or more test case reference in test run 9-1793116/1#13306428/1*/
                  field_value !~
                  '^(([0-9]{1,2}-[0-9]{4,}(\/)[0-9]{1,}#[0-9]{4,}(\/)[0-9]{1,},)?)+([0-9]{1,2}-[0-9]{4,}(\/)[0-9]{1,}#[0-9]{4,}(\/)[0-9]{1,})$' AND
                     /*one or more issue/item [ITEM:1010#3331/1];[ITEM:1011#3332/1]*/
                  field_value !~
                  '^((\[(ITEM|ISSUE):[0-9]{4,}#[0-9]{4,}\/[0-9]{1,}\];)?)+(\[(ITEM|ISSUE):[0-9]{4,}#[0-9]{4,}\/[0-9]{1,}\])$' AND
                     /*Test run ID  label_id:1000104 value:2750e123c70a910cd6278a2c69f53676*/
                  ((label_id < 1000000) OR
                   mod(label_id, 10) != 4 OR
                   field_value !~ '^([0-9]|[a-f]){32}$')));
EXCEPTION
    WHEN OTHERS
        THEN
            RETURN FALSE;
END;
$$;

\set AUTOCOMMIT  FALSE

/*obfuscate acl role*/
UPDATE acl_role SET name=id, description=NULL WHERE
		name <> 'codeBeamer Review Project Review Role'
    AND name <> 'Project Admin'
    AND name <> 'Developer'
    AND name <> 'Stakeholder';
COMMIT;

/*object_reference*/
UPDATE object_reference SET url=CONCAT('file://', from_id) WHERE url LIKE 'file://%';
UPDATE object_reference SET url=CONCAT('mailto:', from_id, '@testemail.testemail') WHERE url LIKE 'mailto:%';
UPDATE object_reference SET url=CONCAT('/', from_id) WHERE url LIKE '\/%';

/*obfuscate urls in wiki fields*/
UPDATE object_reference
SET url = 'url-something'
WHERE to_id IS NULL
AND to_type_id IS NULL
AND assoc_id IS NULL
AND field_id IS NOT NULL;

/*obfuscate usernames in url*/
UPDATE object_reference obj
set url=replace(obj.url, u.name, concat('user-', u.id))
from object_reference obj_ref inner join users u on LOWER(obj_ref.url) like u.name;
COMMIT;

/*remove all file content except: vintage reports, calendar, work calendar*/
TRUNCATE object_revision_blobs;
COMMIT;

/*update name of artifacts except: calendars, work calendar, roles, groups,
  member group, state transition, field definitions, choice option,
  release rank, review config, review tracker, state transition, transition condition,
  workflow action, artifact file link*/
UPDATE object_revision r
SET name = CONCAT(r.object_id,'-artifact ', SUBSTR(r.name, 1, 4), ' :' , LENGTH(r.name))
WHERE r.name NOT IN ('codeBeamer Review Project Review Tracker', 'codeBeamer Review Project Review Item Tracker', 'codeBeamer Review Project Review Config Template Tracker')
	AND r.type_id NOT IN (9, 10, 17, 18, 19, 21, 23, 24, 25, 26, 28, 33, 35, 44);
COMMIT;


/*update description of artifacts, except: calendar, work calendar, state transition,
  transition condition, workflow action*/
UPDATE object_revision r
SET description = jsonb_set(r.description::JSONB,
    '{description}',
    CONCAT('"','Obfuscated description-',LENGTH(r.description::JSON ->> 'description'),'"')::JSONB, FALSE)
WHERE EXISTS(SELECT 1 FROM object o WHERE o.id = r.object_id AND o.type_id NOT IN (9, 10, 17, 23, 24, 28))
	AND IS_VALID_JSON(r.description);
COMMIT;

/*update key, category of projects and trackers*/

UPDATE object_revision r
SET description = jsonb_set(
	jsonb_set(r.description::JSONB, '{keyName}', CONCAT('"K-',r.proj_id,'"')::JSONB, FALSE),
	'{category}',
	'"TestCategory"'::JSONB, FALSE)
WHERE r.type_id IN (22, 16)
	AND IS_VALID_JSON(r.description);
COMMIT;

/*Update categoryName of project categories*/
UPDATE object_revision r
SET description = jsonb_set(r.description::JSONB, '{categoryName}', CONCAT('"', r.name, '"')::JSONB, FALSE)
WHERE r.type_id = 42
	AND IS_VALID_JSON(r.description);
COMMIT;

/*delete simple comment message*/
UPDATE object_revision r
SET description = CONCAT('Obfuscated description-', LENGTH(r.description))
WHERE r.type_id IN (13, 15)
	AND NOT IS_VALID_JSON(r.description);
COMMIT;

/*delete description of : file, folder, baseline, user, tracker, dashboard*/
UPDATE object_revision r
SET description = NULL
WHERE r.type_id IN (1, 2, 12, 30, 31, 32, 34);
COMMIT;

CREATE TEMPORARY TABLE IF NOT EXISTS tmp_jira AS (
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

/*update user data*/
UPDATE users
SET name = CONCAT('user-', id),
	passwd = NULL,
	hostname = NULL,
	firstname = CONCAT('First-', id),
	lastname = CONCAT('Last-', id),
	title = NULL,
	address = NULL,
	zip = NULL,
	city = NULL,
	state = NULL,
	country = NULL,
	language = NULL,
	geo_country = NULL,
	geo_region = NULL,
	geo_city = NULL,
	geo_latitude = NULL,
	geo_longitude = NULL,
	source_of_interest = NULL,
	scc = NULL,
	team_size = NULL,
	division_size = NULL,
	company = NULL,
	email = CONCAT('user', id , '@testemail.testemail'),
	email_client = NULL,
	phone = NULL,
	mobil = NULL,
	skills = NULL,
	unused0 = NULL,
	unused1 = NULL,
	unused2 = NULL,
	referrer_url = NULL
WHERE name NOT IN ('system', 'computed.update', 'deployment.executor', 'scm.executor');
COMMIT;

/*remove user photos*/
TRUNCATE TABLE users_small_photo_blobs;
COMMIT;
TRUNCATE TABLE users_large_photo_blobs;
COMMIT;

/*remove user preferences: DOORS_BRIDGE_LOGIN(63),JIRA_SERVER_LOGIN(67),SLACK_USER_ID(2001),SLACK_USER_TOKEN(2002)*/
DELETE FROM user_pref
WHERE pref_id IN (63, 67, 2001, 2002);
COMMIT;

/*remove user keys*/
TRUNCATE TABLE user_key;
COMMIT;

/*rename projects*/
UPDATE existing
SET name = CONCAT('Project',proj_id),
    key_name = CONCAT('K-' ,proj_id)
WHERE name <> 'codeBeamer Review Project';
COMMIT;


/*remove jira synch*/
TRUNCATE TABLE object_job_schedule;
COMMIT;

/*update task summary and description*/
UPDATE task
SET summary = CONCAT('Task',id,' ', SUBSTR(summary, 1, 4), ' :' ,LENGTH(summary))
WHERE summary IS NOT NULL;
COMMIT;


UPDATE task
SET details = CAST(LENGTH(details) AS VARCHAR)
WHERE details IS NOT NULL;
COMMIT;


/*UPDATE custom field value (not choice data)*/

UPDATE task_field_value
SET field_value = (
    CASE
        WHEN TRIM(TRANSLATE(SUBSTR(field_value, 1, 100), '0123456789-,.', ' ')) IS NULL
            THEN '1'
        ELSE CONCAT(SUBSTR(field_value, 1, 2), ' :', LENGTH(field_value))
        END)
WHERE field_value IS NOT NULL
  AND SHOULD_OBFUSCATE(field_value, label_id)
  AND (label_id in (3, 80) OR label_id >= 1000);
COMMIT;


/*UPDATE summary, description and custom field value*/
UPDATE task_field_history
SET old_value = (
    CASE
        WHEN old_value IS NOT NULL AND SHOULD_OBFUSCATE(old_value, label_id) THEN (
            CASE
                WHEN TRIM(TRANSLATE(SUBSTR(old_value, 1, 100), '0123456789-,.', ' ')) IS NULL
                    THEN CAST(revision - 1 AS TEXT)
                ELSE CONCAT(SUBSTR(old_value, 1, 2), ' :', LENGTH(old_value))
                END)
        ELSE old_value
        END
    ),
    new_value = (
        CASE
            WHEN new_value IS NOT NULL AND SHOULD_OBFUSCATE(new_value, label_id) THEN (
                CASE
                    WHEN TRIM(TRANSLATE(SUBSTR(new_value, 1, 100), '0123456789-,.', ' ')) IS NULL
                        THEN CAST(revision AS TEXT)
                    ELSE CONCAT(SUBSTR(new_value, 1, 2), ' :', LENGTH(new_value))
                    END)
            ELSE new_value
            END
        )
WHERE label_id IN (3, 80)
   OR (label_id >= 1000);
COMMIT;


/*TASK_TYPE reduce prefix to 2 characters*/
UPDATE task_type SET prefix=SUBSTR(prefix, 1, 2);
COMMIT;

/*remove report jobs*/
TRUNCATE TABLE object_quartz_schedule;
COMMIT;


/*UPDATE tag name*/
UPDATE label
SET name = CONCAT('LABEL', id)
WHERE name NOT IN ('FINISHED_TESTRUN_GENERATION');
COMMIT;


UPDATE workingset
SET name = CONCAT('WS-', id), description = NULL
WHERE name != 'member';
COMMIT;

TRUNCATE TABLE document_cache_data_blobs, document_cache_data;
COMMIT;

TRUNCATE TABLE background_job, background_step,background_step_result,background_step_context,background_job_meta;
COMMIT;

/*remove stored configs*/
TRUNCATE TABLE application_configuration;
COMMIT;

DROP FUNCTION IF EXISTS RANDOM_STRING;
DROP FUNCTION IF EXISTS SHOULD_OBFUSCATE;
DROP FUNCTION IF EXISTS IS_VALID_JSON;
COMMIT;
