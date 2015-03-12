select acs_log__debug('/packages/intranet-cust-flyhh/sql/postgresql/upgrade/upgrade-4.1.0.0.5-4.1.0.0.6.sql','');


CREATE OR REPLACE FUNCTION inline_0 ()
RETURNS INTEGER AS
$$
declare
    v_count integer;
begin
    select count(*) into v_count
    from	 user_tab_columns 
    where lower(table_name) = 'flyhh_event_participants'
    and lower(column_name) = 'sort_order';
    IF 0 != v_count THEN return 0; END IF;

    alter table flyhh_event_participants
    add column sort_order            integer;

    return 1;

end;
$$ LANGUAGE 'plpgsql';

SELECT inline_0 ();
DROP FUNCTION inline_0 ();

update flyhh_event_participants set sort_order = participant_id where sort_order is null;
update im_view_columns set column_name = 'Room', column_render_tcl = '$room_html', sort_order = 6, order_by_clause = 'ep.room_id' where column_id = 300008;


CREATE OR REPLACE FUNCTION inline_0 ()
RETURNS INTEGER AS
$$
declare
    v_count integer;
    row record;
begin
    select count(*) into v_count
    from	 user_tab_columns 
    where lower(table_name) = 'flyhh_event_room_occupants';
    
    IF 0 != v_count THEN return 0; END IF;
    
    create table flyhh_event_room_occupants (
        room_id             integer not null,
        person_id           integer not null,
        project_id          integer not null,
        note         text
    );
    
    create unique index flyhh_event_room_occupants_pk on flyhh_event_room_occupants (room_id, person_id, project_id);

    for row in
        select person_id,room_id,project_id
        from flyhh_event_participants
        where room_id is not null
    loop
        insert into flyhh_event_room_occupants (room_id,person_id,project_id) values (row.room_id,row.person_id,row.project_id);
    end loop;

    alter table flyhh_event_participants drop column room_id;
    
    return 1;    
end;
$$ LANGUAGE 'plpgsql';

SELECT inline_0 ();
DROP FUNCTION inline_0 ();