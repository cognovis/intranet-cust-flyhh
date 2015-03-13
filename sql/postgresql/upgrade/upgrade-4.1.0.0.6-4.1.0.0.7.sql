select acs_log__debug('/packages/intranet-cust-flyhh/sql/postgresql/upgrade/upgrade-4.1.0.0.6-4.1.0.0.7.sql','');


CREATE OR REPLACE FUNCTION inline_0 ()
RETURNS INTEGER AS
$$
declare
    v_count integer;
begin
    select count(*) into v_count
    from	 user_tab_columns 
    where lower(table_name) = 'flyhh_event_participants'
    and lower(column_name) = 'alternative_accommodation';
    IF 0 != v_count THEN return 0; END IF;

    alter table flyhh_event_participants
    add column alternative_accommodation text;

    return 1;

end;
$$ LANGUAGE 'plpgsql';

SELECT inline_0 ();
DROP FUNCTION inline_0 ();

update im_view_columns set column_name = 'Alternativ Accommodation', column_render_tcl = '$alterantive_accommodation_html' where column_id = 300006;
