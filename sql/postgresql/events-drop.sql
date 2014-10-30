

drop function flyhh_event__update(integer,varchar,integer,boolean);
drop function flyhh_event__new(integer,varchar,integer,varchar,integer,boolean);

-- on delete cascade will make sure all flyhh_events rows are deleted
-- when the corresponding project row is deleted
select im_project__delete(project_id) from flyhh_events;
drop table flyhh_events;

select flyhh__drop_type('flyhh_event');

