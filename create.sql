--- create history table for alarms
CREATE TABLE alarms_history (
    alarm_alarmid integer NOT NULL,
    alarm_eventuei character varying(256) NOT NULL,
    alarm_node integer,
    alarm_severity integer NOT NULL,
    alarm_logmsg text,
    content_stickymemo text,
    user_acknowleged text,
    user_stickymemo text,
    user_cleared text,
    time_alarm_created timestamp with time zone,
    time_alarm_acknowleged timestamp with time zone,
    time_alarm_stickycreated timestamp with time zone,
    time_alarm_cleared timestamp with time zone,
    time_alarm_removed timestamp with time zone
);

--- set owner of the new table to user opennms
ALTER TABLE alarms_history OWNER TO opennms;

--- create function for inserting alarms to new history table
CREATE OR REPLACE FUNCTION copy_alarm() RETURNS TRIGGER AS $copy_alarm$
    BEGIN
        --- on insert: insert problem alarms in alarm history
        IF (TG_OP = 'INSERT' AND NEW.alarmtype IN (1,3)) THEN
            INSERT INTO alarms_history 
                SELECT NEW.alarmid, NEW.eventuei, NEW.nodeid, NEW.severity, NEW.logmsg, 
                       NULL, NULL, NULL, NULL,
                       NOW(), NULL, NULL, NULL, NULL;
            RETURN NULL;
        --- on update: handle alarm clearing
        ELSIF (TG_OP = 'UPDATE' AND NEW.alarmtype in (1,3) AND OLD.severity != NEW.severity
                                AND NEW.severity = 2) THEN
            UPDATE alarms_history set time_alarm_cleared = NOW(),
                user_cleared=(SELECT ackuser FROM acks 
                                    WHERE refid=NEW.alarmid 
                                    AND ackaction=4 ORDER BY acktime DESC limit 1)
                WHERE alarm_alarmid=NEW.alarmid;
            RETURN NULL;
        --- on update: handle alarm acknowlegding
        ELSIF (TG_OP = 'UPDATE' AND NEW.alarmtype in (1,3) AND OLD.alarmacktime is NULL
                                AND NEW.alarmacktime is not NULL) THEN
            UPDATE alarms_history set time_alarm_acknowleged = NOW(), user_acknowleged=NEW.alarmackuser 
                WHERE alarm_alarmid=NEW.alarmid;
            RETURN NULL;
        -- on update: handle sticky memo
        ELSIF (TG_OP = 'UPDATE' AND NEW.alarmtype in (1,3) AND OLD.stickymemo is NULL
                                AND NEW.stickymemo is not NULL) THEN
            UPDATE alarms_history set content_stickymemo=(SELECT body from memos WHERE id=NEW.stickymemo),
                user_stickymemo=(SELECT author from memos WHERE id=NEW.stickymemo), 
                time_alarm_stickycreated=NOW()
                WHERE alarm_alarmid=NEW.alarmid;
            RETURN NULL;
        -- on delete: set alarm removed timestamp
        ELSIF (TG_OP = 'DELETE' AND OLD.alarmtype in (1,3)) THEN
            UPDATE alarms_history set time_alarm_removed = NOW() WHERE alarm_alarmid=OLD.alarmid;
            RETURN NULL;
        END IF;
        RETURN NULL;
    END;
$copy_alarm$ LANGUAGE plpgsql;

--- create trigger
CREATE TRIGGER alarms_history 
    AFTER INSERT OR UPDATE OR DELETE ON alarms
    FOR EACH ROW
    EXECUTE PROCEDURE copy_alarm();
