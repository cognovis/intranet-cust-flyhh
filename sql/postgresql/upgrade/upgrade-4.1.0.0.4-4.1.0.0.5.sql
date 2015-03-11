select acs_log__debug('/packages/intranet-cust-flyhh/sql/postgresql/upgrade/upgrade-4.1.0.0.4-4.1.0.0.5.sql','');


CREATE OR REPLACE FUNCTION inline_0 ()
RETURNS INTEGER AS
$$
declare
    v_count integer;
begin
    select count(*) into v_count
    from	 user_tab_columns 
    where lower(table_name) = 'flyhh_event_rooms'
    and lower(column_name) = 'room_office_id';
    IF 0 != v_count THEN return 0; END IF;

    alter table flyhh_event_rooms
    add column room_office_id            integer
    constraint flyhh_event_room_office_id_fk
    references im_offices(office_id);

    return 1;

end;
$$ LANGUAGE 'plpgsql';

SELECT inline_0 ();
DROP FUNCTION inline_0 ();

select im_category_new(175,'Event Location','Intranet Office Type') from dual;

update im_offices set office_type_id = 175 where company_id = 41516;

