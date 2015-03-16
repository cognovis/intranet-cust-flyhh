select acs_log__debug('/packages/intranet-cust-flyhh/sql/postgresql/upgrade/upgrade-4.1.0.0.7-4.1.0.0.8.sql','');


CREATE OR REPLACE FUNCTION inline_0 ()
RETURNS INTEGER AS
$$
declare
    v_count integer;
begin
    select count(*) into v_count
    from	 user_tab_columns 
    where lower(table_name) = 'flyhh_events'
    and lower(column_name) = 'facebook_event_url';
    IF 0 != v_count THEN return 0; END IF;

    alter table flyhh_events
    add column facebook_event_url varchar(150);

    return 1;

end;
$$ LANGUAGE 'plpgsql';

SELECT inline_0 ();
DROP FUNCTION inline_0 ();

CREATE OR REPLACE FUNCTION inline_0 ()
RETURNS INTEGER AS
$$
declare
    v_count integer;
begin
    select count(*) into v_count
    from	 user_tab_columns 
    where lower(table_name) = 'flyhh_events'
    and lower(column_name) = 'facebook_orga_url';
    IF 0 != v_count THEN return 0; END IF;

    alter table flyhh_events
    add column facebook_orga_url varchar(150);

    return 1;

end;
$$ LANGUAGE 'plpgsql';

SELECT inline_0 ();
DROP FUNCTION inline_0 ();

update flyhh_events set facebook_event_url = 'www.facebook.com/events/875454432506211' where project_id = '39650';
update flyhh_events set facebook_event_url = 'www.facebook.com/events/1593990024175373' where project_id = '39660';

update flyhh_events set facebook_orga_url = 'www.facebook.com/BalboaCastleCamp' where project_id = '39650';
update flyhh_events set facebook_orga_url = 'www.facebook.com/swingcastlecamp' where project_id = '39660';
    
update im_projects set start_date = (select start_date from flyhh_events where project_id = '39650') where project_id = 39650;
update im_projects set start_date = (select start_date from flyhh_events where project_id = '39660') where project_id = 39660;

CREATE OR REPLACE FUNCTION inline_0 ()
RETURNS INTEGER AS
$$
declare
    v_count integer;
begin
    select count(*) into v_count
    from	 user_tab_columns 
    where lower(table_name) = 'flyhh_events'
    and lower(column_name) = 'start_date';
    IF 0 == v_count THEN return 0; END IF;

    alter table flyhh_events
    drop column start_date;

    return 1;

end;
$$ LANGUAGE 'plpgsql';