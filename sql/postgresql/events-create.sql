-- @author Neophytos Demetriou
-- @creation-date 2014-10-30
-- @last-modified 2014-10-30

select acs_object_type__create_type (
        'flyhh_event',          -- object_type
        'Flyhh - Event',        -- pretty_name
        'Flyhh - Events',       -- pretty_plural
        'im_biz_object',        -- supertype
        'flyhh_events',         -- table_name
        'event_id',             -- id_column
        'flyhh_event',          -- pl/pgsql package_name
        'f',                    -- abstract_p
        null,                   -- type_extension_table
        'flyhh_event__name'     -- name_method
);

insert into acs_object_type_tables (object_type,table_name,id_column)
values ('flyhh_event', 'flyhh_events', 'event_id');

update acs_object_types set
        status_type_table = 'flyhh_events',
        status_column = 'status_id',
        type_column = 'type_id'
where object_type = 'flyhh_event';

---insert into im_biz_object_urls (object_type, url_type, url) values (
---'im_project','view','/flyhh/admin/participants/view?person_id=');
---insert into im_biz_object_urls (object_type, url_type, url) values (
---'im_project','edit','/flyhh/admin/participants/new?project_id=');

create table flyhh_events (
    event_id            integer
                        constraint flyhh_events_pk
                        primary key,

    event_title         varchar(250) not null,

    -- one project per event 
    
	project_id			integer not null
                        constraint flyhh_event_participants__project_fk
                        references im_projects(project_id),

	-- tracks the status of the event

    status_id           integer not null 
                        constraint flyhh_event_participants__status_fk 
                        references im_categories(category_id),

    type_id             integer not null 
                        constraint flyhh_event_participants__type_fk 
                        references im_categories(category_id)

); 


