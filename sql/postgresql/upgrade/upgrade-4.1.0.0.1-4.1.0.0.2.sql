select acs_log__debug('/packages/intranet-cust-flyhh/sql/postgresql/upgrade/upgrade-4.1.0.0.1-4.1.0.0.2.sql','');

update im_dynfield_widgets set parameters = '{custom {sql {SELECT m.material_id,material_name FROM im_materials m, flyhh_event_materials f,flyhh_events e WHERE m.material_type_id=(SELECT material_type_id FROM im_material_types WHERE material_type=''Course Income'') and f.material_id = m.material_id and f.event_id = e.event_id and e.project_id = :project_id and f.capacity >0}}}' where widget_name = 'flyhh_event_participant_course';

update im_dynfield_widgets set parameters = '{custom {sql {SELECT m.material_id,material_name FROM im_materials m, flyhh_event_materials f,flyhh_events e WHERE m.material_type_id=(SELECT material_type_id FROM im_material_types WHERE material_type=''Accomodation'') and f.material_id = m.material_id and f.event_id = e.event_id and e.project_id = :project_id and f.capacity >0}}}' where widget_name = 'flyhh_event_participant_accommodation';


update im_dynfield_widgets set parameters = '{custom {sql {SELECT m.material_id,material_name FROM im_materials m, flyhh_event_materials f,flyhh_events e WHERE m.material_type_id=(SELECT material_type_id FROM im_material_types WHERE material_type=''Food Choice'') and f.material_id = m.material_id and f.event_id = e.event_id and e.project_id = :project_id and f.capacity >0}}}' where widget_name = 'flyhh_event_participant_food_choice';

update im_dynfield_widgets set parameters = '{custom {sql {SELECT m.material_id,material_name FROM im_materials m, flyhh_event_materials f,flyhh_events e WHERE m.material_type_id=(SELECT material_type_id FROM im_material_types WHERE material_type=''Flyhh - Event Participant Level'') and f.material_id = m.material_id and f.event_id = e.event_id and e.project_id = :project_id and f.capacity >0}}}' where widget_name = 'flyhh_event_participant_levels';

CREATE OR REPLACE FUNCTION inline_0 ()
RETURNS INTEGER AS
$$
declare
    v_count integer;
begin
    select count(*) into v_count
    from	 user_tab_columns 
    where lower(table_name) = 'flyhh_event_participants'
    and lower(column_name) = 'invoice_id';
    IF 0 != v_count THEN return 0; END IF;

    alter table flyhh_event_participants
    add column invoice_id            integer
    constraint flyhh_event_participants_invoice_id_fk
    references im_invoices(invoice_id);

    return 1;

end;
$$ LANGUAGE 'plpgsql';

update im_categories set category = 'Skill' where category_id = 11504;
update im_categories set category = 'Accomodation' where category_id = 11506;


update im_view_columns set extra_select = '''<a href="/intranet-invoices/view?invoice_id='' || invoice_id || ''">latest invoice</a>'' as latest_invoice_html, ''<a href="/intranet-invoices/view?invoice_id='' || order_id || ''\">purchase order</a>'' as purchase_order_html' where variable_name ='event_participant_status_id' and column_name = 'Status'

CREATE OR REPLACE FUNCTION inline_0 ()
RETURNS INTEGER AS
$$
declare
    v_count integer;
begin
    select count(*) into v_count
    from	 user_tab_columns 
    where lower(table_name) = 'flyhh_events'
    and lower(column_name) = 'event_url';
    IF 0 != v_count THEN return 0; END IF;

    alter table flyhh_events
    add column event_url varchar(200);

    return 0;

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
    and lower(column_name) = 'event_email';
    IF 0 != v_count THEN return 0; END IF;

    alter table flyhh_events
    add column event_email varchar(200);

    return 0;

end;
$$ LANGUAGE 'plpgsql';

SELECT inline_0 ();
DROP FUNCTION inline_0 ();

CREATE OR REPLACE FUNCTION inline_0 ()
RETURNS INTEGER AS
$$
declare
begin
perform im_component_plugin__new (
        null,                               -- plugin_id
        'im_component_plugin',              -- object_type
        now(),                              -- creation_date
        null,                               -- creation_user
        null,                               -- creation_ip
        null,                               -- context_id
        'Event Registration Notes',                 -- plugin_name
        'intranet-notes',              -- package_name
        'right',                             -- location
        '/flyhh/admin/registration',             -- page_url
        null,                               -- view_name
        20,                                 -- sort_order
        E'im_notes_component -object_id participant_id'     -- component_tcl
    );
    
    return 1;
end;
$$ LANGUAGE 'plpgsql';

SELECT inline_0 ();
DROP FUNCTION inline_0 ();

create or replace function flyhh_event__new(
    p_event_id          integer,
    p_event_name        varchar,
    p_company_id        integer,
    p_project_nr        varchar,
    p_cost_center_id    integer,
    p_enabled_p         boolean
) returns boolean as 
$$
declare
    v_project_id        integer;
begin

    select im_project__new(
        null,               -- project_id
        'im_project',     -- object_type
        now(),              -- creation_date
        null,               -- creation_user
        null,               -- creation_ip
        null,               -- context_id
        p_event_name,   -- project_name
        p_project_nr,       -- project_nr
        p_project_nr,       -- project_path
        null,               -- parent_id
        p_company_id,       -- company_id
        '102',              -- project_type_id (=Castle Camp)
        76                  -- project_status_id (=Open)
      ) into v_project_id;

    update im_projects 
    set project_cost_center_id=p_cost_center_id 
    where project_id=v_project_id;

    insert into flyhh_events (
        event_id,
        event_name,
        project_id,
        enabled_p
    ) values (
        p_event_id,
        p_event_name,
        v_project_id,
        p_enabled_p
    );

    return true;

end;
$$ language 'plpgsql';

update im_categories set category = 'Accommodation' where category_id = 9002;