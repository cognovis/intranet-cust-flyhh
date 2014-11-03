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

    event_name          varchar(250) not null,

    -- one project per event 
    
	project_id			integer not null
                        constraint flyhh_event_participants__project_fk
                        references im_projects(project_id) on delete cascade,

    enabled_p           boolean not null default 'f'

); 

-- we query for the event_name using project_id
create index flyhh_events__project_id__idx on flyhh_events(project_id);

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
        'Event Project: ' || p_event_name,   -- project_name
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

create or replace function flyhh_event__update(
    p_event_id          integer,
    p_event_name        varchar,
    p_project_type_id   integer,
    p_enabled_p         boolean
) returns boolean as 
$$
begin

    -- TODO: update corresponding project record

    update flyhh_events set
        event_name = p_event_name,
        enabled_p = p_enabled_p
    where
        event_id = p_event_id;

    return true;

end;
$$ language 'plpgsql';

create or replace function flyhh_event__name(
    p_event_id          integer
) returns varchar as
$$
begin
    return event_name from flyhh_events where event_id=p_event_id;
end;
$$ language 'plpgsql';

-- one project per event
create or replace function flyhh_event__name_from_project_id(
    p_project_id        integer
) returns varchar as
$$
begin
    return event_name from flyhh_events where project_id=p_project_id;
end;
$$ language 'plpgsql';


