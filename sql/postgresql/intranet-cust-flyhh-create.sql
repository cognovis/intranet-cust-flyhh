select acs_object_type__create_type (
        'im_event_participant',         -- object_type
        'Event Participant',            -- pretty_name
        'Event Participants',           -- pretty_plural
        'im_biz_object',                -- supertype
        'im_event_participants',        -- table_name
        'person_id',      		-- id_column
        'intranet-cust-flyhh', 		-- package_name
        'f',                            -- abstract_p
        null,                           -- type_extension_table
        'im_event_participant__name'    -- name_method
);

insert into acs_object_type_tables (object_type,table_name,id_column)
values ('im_event_participant', 'im_event_participants', 'person_id');

update acs_object_types set
        status_type_table = 'im_event_participants',
        status_column = 'event_participant_status_id',
        type_column = 'event_participant_type_id'
where object_type = 'im_event_participant';

---insert into im_biz_object_urls (object_type, url_type, url) values (
---'im_project','view','/flyhh/admin/participants/view?person_id=');
---insert into im_biz_object_urls (object_type, url_type, url) values (
---'im_project','edit','/flyhh/admin/participants/new?project_id=');



create table im_event_participants (
        user_id				integer
                                	constraint im_event_participants_pk
                                	primary key
                                	constraint im_event_participants_fk
                                	references users(user_id),

	project_id			integer
					constraint im_event_participants__project_fk
					references im_projects(project_id),

	--- tracks the status of the participant for that event
        event_participant_status_id     integer not null 
                                        constraint im_event_participants__status_fk 
                                        references im_categories,

	--- define the dynfields which are supposed to show up
	--- we use the aux_int1 field of the event_participant_type_id (aka: category_id) 
	--- to link the event_participant type to the project_type_id 
	--- (otherwise we would not know which dynfields to show for a project).
        event_participant_type_id     integer not null 
                                      constraint im_event_participants__type_fk 
                                      references im_categories


);

-- Optional Indices for larger systems:
-- create index im_event_participants_status_id_idx on im_event_participants(event_participant_status_id);
-- create index im_event_participants_type_id_idx on im_event_participants(event_participant_type_id);

-- ------------------------------------------------------------
-- Event Participant Package
-- ------------------------------------------------------------

create or replace function im_event_participants__new (
        integer, varchar, timestamptz, integer, varchar, integer,
	integer, integer, integer
) returns integer as '
DECLARE
        p_person_id     alias for $1;
        p_object_type   alias for $2;
        p_creation_date alias for $3;
        p_creation_user alias for $4;
        p_creation_ip   alias for $5;
        p_context_id    alias for $6;

        p_project_id   alias for $7;
        p_status_id    alias for $8;
        p_type_id      alias for $9;

        v_person_id    integer;
BEGIN
        v_person_id := acs_object__new (
                p_person_id,
                p_object_type,
                p_creation_date,
                p_creation_user,
                p_creation_ip,
                p_context_id
        );

        insert into im_biz_objects (object_id) values (v_person_id);

        insert into im_event_participants (
                person_id, 
		project_id,
		event_participant_status_id,
		event_participant_type_id
        ) values (
                v_person_id, 
		p_project_id,
		p_event_participant_status_id,
		p_event_participant_type_id
        );
        return v_person_id;
end;' language 'plpgsql';




create or replace function im_event_participant__name (integer) 
returns varchar as '
DECLARE
        p_person_id alias for $1;
        v_name  varchar;
BEGIN
        select  first_names || last_name
        into    v_name
        from    persons
        where   person_id = p_person_id;

        return v_name;
end;' language 'plpgsql';

--- We use the task_type_id referencing the project_type_id from the project which we create for the event.
--- We have one project type called „Castle Camp“ with two sub categories „SCC“ and „BCC“. 
--- When we create the event, we will have a project which then has the project type of either „SCC“ or „BCC“. 
--- Materials which can be used for both (e.g. the accommodation materials) will then have a the task_type_id 
--- of the „Castle Camp“ category, whereas the other ones have the one specific to them. 

SELECT im_category_new (102, 'Castle Camp', 'Intranet Project Type');
SELECT im_category_new (103, 'SCC', 'Intranet Project Type');
SELECT im_category_new (104, 'BCC', 'Intranet Project Type');

SELECT im_category_hierarchy_new (103, 102);
SELECT im_category_hierarchy_new (104, 102);



