select acs_log__debug('/packages/intranet-cust-flyhh/sql/postgresql/upgrade/upgrade-4.1.0.0.1-4.1.0.0.2.sql','');

update im_dynfield_widgets set parameters = '{custom {sql {SELECT m.material_id,material_name FROM im_materials m, flyhh_event_materials f,flyhh_events e WHERE m.material_type_id=(SELECT material_type_id FROM im_material_types WHERE material_type=''Course Income'') and f.material_id = m.material_id and f.event_id = e.event_id and e.project_id = :project_id and f.capacity >0}}}' where widget_name = 'flyhh_event_participant_course';

update im_dynfield_widgets set parameters = '{custom {sql {SELECT m.material_id,material_name FROM im_materials m, flyhh_event_materials f,flyhh_events e WHERE m.material_type_id=(SELECT material_type_id FROM im_material_types WHERE material_type=''Accomodation'') and f.material_id = m.material_id and f.event_id = e.event_id and e.project_id = :project_id and f.capacity >0}}}' where widget_name = 'flyhh_event_participant_accommodation';


update im_dynfield_widgets set parameters = '{custom {sql {SELECT m.material_id,material_name FROM im_materials m, flyhh_event_materials f,flyhh_events e WHERE m.material_type_id=(SELECT material_type_id FROM im_material_types WHERE material_type=''Food Choice'') and f.material_id = m.material_id and f.event_id = e.event_id and e.project_id = :project_id and f.capacity >0}}}' where widget_name = 'flyhh_event_participant_food_choice';

update im_dynfield_widgets set parameters = '{custom {sql {SELECT m.material_id,material_name FROM im_materials m, flyhh_event_materials f,flyhh_events e WHERE m.material_type_id=(SELECT material_type_id FROM im_material_types WHERE material_type=''Flyhh - Event Participant Level'') and f.material_id = m.material_id and f.event_id = e.event_id and e.project_id = :project_id and f.capacity >0}}}' where widget_name = 'flyhh_event_participant_levels';
    
create or replace function inline_0 ()
returns integer as '
declare
    v_count		integer;
begin
    select	count(*) into v_count
    from	user_tab_columns 
where	lower(table_name) = ''flyhh_event_participants'' and 
    lower(column_name) = ''invoice_id'';
    IF 0 != v_count THEN return 0; END IF;

    alter table flyhh_event_participants
    add column invoice_id            integer
    constraint flyhh_event_participants_invoice_id_fk
    references im_invoices(invoice_id);

    return 0;
end;' language 'plpgsql';
select inline_0 ();
drop function inline_0 ();


update im_view_columns set extra_select = '''<a href="/intranet-invoices/view?invoice_id='' || invoice_id || ''">latest invoice</a>'' as latest_invoice_html, ''<a href="/intranet-invoices/view?invoice_id='' || order_id || ''\">purchase order</a>'' as purchase_order_html' where variable_name ='event_participant_status_id' and column_name = 'Status'