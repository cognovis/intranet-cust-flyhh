

drop function flyhh_event__update(integer,varchar,integer,boolean);
drop function flyhh_event__new(integer,varchar,integer,varchar,integer,boolean);

select acs_rel__delete(rel_id) from acs_rels where object_id_one in (select cost_id from im_costs where project_id in (select project_id from flyhh_events));
delete from im_invoice_items where invoice_id in (select cost_id from im_costs where project_id in (select project_id from flyhh_events));
select acs_object__delete(cost_id),im_invoice__delete(cost_id),im_cost__delete(cost_id) from im_costs where project_id in (select project_id from flyhh_events);

-- on delete cascade will make sure all flyhh_events rows are deleted
-- when the corresponding project row is deleted
select im_project__delete(project_id) from flyhh_events;
drop table flyhh_event_materials;
drop table flyhh_events;

select flyhh__drop_type('flyhh_event');

