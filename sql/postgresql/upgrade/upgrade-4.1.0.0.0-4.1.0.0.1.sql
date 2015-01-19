SELECT acs_log__debug('/packages/intranet-cust-flyhh/sql/postgresql/upgrade/upgrade-4.1.0.0.0-4.1.0.0.1.sql','');
create table flyhh_event_materials (
    event_id            integer
                        constraint flyhh_event_materials__event_id_fk
                        references flyhh_events(event_id) on delete cascade,

    material_id         integer
                        constraint flyhh_event_materials__material_id_fk
                        references im_materials(material_id),

    capacity            integer,

    -- status is in "Confirmed", "Pending Payment", or "Partially Paid"
    num_confirmed       integer not null default 0,

    -- status is in "Registered"
    num_registered      integer not null default 0,

    -- capacity - num_registered
    free_capacity       integer,

    -- capacity - (num_registered + num_confirmed)
    free_confirmed_capacity integer

);

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

    update im_projects set
        project_cost_center_id=p_cost_center_id,
        project_lead_id = (select company_contact_id from im_companies where company_id=p_company_id)
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


-- 
-- Add a new project type
--
SELECT im_category_new ('2520', 'Event', 'Intranet Project Type');

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
        '2520',              -- project_type_id (=Event)
        76                  -- project_status_id (=Open)
      ) into v_project_id;

    update im_projects set
        project_cost_center_id=p_cost_center_id,
        project_lead_id = (select company_contact_id from im_companies where company_id=p_company_id)
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

-- add the dynfield attributes and default to consulting project
delete from im_dynfield_type_attribute_map where object_type_id = 2520;
    
INSERT INTO im_dynfield_type_attribute_map
    (attribute_id, object_type_id, display_mode, help_text,section_heading,default_value,required_p)
select attribute_id,2520,display_mode,help_text,section_heading,default_value,required_p from im_dynfield_type_attribute_map where object_type_id = 2501;
