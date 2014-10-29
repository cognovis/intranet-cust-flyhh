--- @author Neophytos Demetriou
--- @creation-date 2014-10-15
--- @last-modified 2014-10-28

select acs_object_type__create_type (
        'flyhh_event_participant',      -- object_type
        'Flyhh - Event Participant',    -- pretty_name
        'Flyhh - Event Participants',   -- pretty_plural
        'im_biz_object',                -- supertype
        'flyhh_event_participants',     -- table_name
        'person_id',      		        -- id_column
        'intranet-cust-flyhh', 		    -- package_name
        'f',                            -- abstract_p
        null,                           -- type_extension_table
        'flyhh_event_participant__name'    -- name_method
);

insert into acs_object_type_tables (object_type,table_name,id_column)
values ('flyhh_event_participant', 'flyhh_event_participants', 'person_id');

update acs_object_types set
        status_type_table = 'flyhh_event_participants',
        status_column = 'event_participant_status_id',
        type_column = 'event_participant_type_id'
where object_type = 'flyhh_event_participant';

---insert into im_biz_object_urls (object_type, url_type, url) values (
---'im_project','view','/flyhh/admin/participants/view?person_id=');
---insert into im_biz_object_urls (object_type, url_type, url) values (
---'im_project','edit','/flyhh/admin/participants/new?project_id=');



create table flyhh_event_participants (
    participant_id      integer not null
                        constraint flyhh_event_participants_pk
                        primary key,

    person_id			integer not null
                        constraint flyhh_event_participants_person_id_fk
                        references persons(person_id),

    -- one project per event 
    
	project_id			integer not null
                        constraint flyhh_event_participants__project_fk
                        references im_projects(project_id),

	-- tracks the status of the participant for that event

    event_participant_status_id     integer not null 
                                    constraint flyhh_event_participants__status_fk 
                                    references im_categories(category_id),

	-- define the dynfields which are supposed to show up
	-- we use the aux_int1 field of the event_participant_type_id (aka: category_id) 
	-- to link the event_participant type to the project_type_id 
	-- (otherwise we would not know which dynfields to show for a project).

    event_participant_type_id     integer not null 
                                  constraint flyhh_event_participants__type_fk 
                                  references im_categories(category_id),

    validation_mask             integer not null,


    accommodation       integer
                        constraint flyhh_event_participants__accommodation_fk
                        references im_materials(material_id),

    food_choice         integer
                        constraint flyhh_event_participants__food_choice_fk
                        references im_materials(material_id),
    
    bus_option          integer
                        constraint flyhh_event_participants__bus_option_fk
                        references im_materials(material_id),

    level   integer
                        constraint flyhh_event_participants__level_fk
                        references im_categories(category_id),
    
    

    payment_type        integer
                        constraint flyhh_event_participants__payment_type_fk
                        references im_categories(category_id),
    
    payment_term        integer
                        constraint flyhh_event_participants__payment_term_fk
                        references im_categories(category_id),
    
    lead_p              boolean not null default 'f',

    -- partner_name is different than partner_person_name (see participant-list.tcl)
    -- the former is given by the participant as the name of their partner
    -- the latter is the name we have on record for a user account

    partner_text        varchar(250),

    partner_name        varchar(250),

    partner_email       varchar(250),

    partner_participant_id integer
                        constraint flyhh_event_participants__partner_participant_id_fk
                        references flyhh_event_participants(participant_id),
    
    partner_person_id   integer
                        constraint flyhh_event_participants__partner_person_id_fk
                        references persons(person_id),

    -- if all we've got is the partner's name and the search returned
    -- more than one participant with the given name, we set this flag
    -- in order to mark the value as such in the user interface
    partner_mutual_p    boolean default 'f',

    accepted_terms_p    boolean not null default 'f',

    invalid_partner_p   boolean not null default 'f',

    invalid_roommates_p boolean not null default 'f',

    mismatch_accomm_p   boolean not null default 'f',

    mismatch_lead_p     boolean not null default 'f',

    mismatch_level_p    boolean not null default 'f'

);

-- event participant roommates map

create table flyhh_event_roommates (

    participant_id      integer not null
                        constraint flyhh_event_roommates__participant_id_fk
                        references flyhh_event_participants(participant_id),

    -- project_id is available via participant_id but convenient to have it here

	project_id			integer not null
                        constraint flyhh_event_participants__project_fk
                        references im_projects(project_id),
    
    roommate_email      varchar(250) not null,

    roommate_person_id  integer
                        constraint flyhh_event_roommates__person_id_fk
                        references persons(person_id),

    roommate_id         integer
                        constraint flyhh_event_roommates__roommate_id_fk
                        references flyhh_event_participants(participant_id)

);

-- Optional Indices for larger systems:
-- create index flyhh_event_participants_status_id_idx on flyhh_event_participants(event_participant_status_id);
-- create index flyhh_event_participants_type_id_idx on flyhh_event_participants(event_participant_type_id);

-- ------------------------------------------------------------
-- Event Participant Package
-- ------------------------------------------------------------

-- im_biz_object__new is ill-defined in dump for flyhh, 
-- even though it is correct in intranet-biz-objects.sql (intranet-core)

create or replace function im_biz_object__new (integer,varchar,timestamptz,integer,varchar,integer)
returns integer as '
declare
        p_object_id     alias for $1;
        p_object_type   alias for $2;
        p_creation_date alias for $3;
        p_creation_user alias for $4;
        p_creation_ip   alias for $5;
        p_context_id    alias for $6;

        v_object_id     integer;
begin
        v_object_id := acs_object__new (
                p_object_id,
                p_object_type,
                p_creation_date,
                p_creation_user,
                p_creation_ip,
                p_context_id
        );
        insert into im_biz_objects (object_id) values (v_object_id);
        return v_object_id;

end;' language 'plpgsql';


-- TODO: we can also check whether roommates choose the same type of accommodation
-- and whether roommates have chosen different people to stay with.

create or replace function flyhh_event_participant__status_automaton (
    integer
) returns boolean as '
declare

    p_participant_id                alias for $1;

    v_invalid_both_p                boolean;
    v_invalid_partner_p             boolean;
    v_invalid_roommates_p           boolean;
    v_mismatch_lead_p               boolean;
    v_mismatch_accommodation_p      boolean;
    v_mismatch_level_p              boolean;
    v_category                      varchar;

begin

    select case when partner_participant_id is null then true else false end into v_invalid_partner_p
    from flyhh_event_participants
    where participant_id = p_participant_id;

    select case when count(1)>0 then true else false end into v_invalid_roommates_p
    from flyhh_event_roommates
    where participant_id = p_participant_id
    and roommate_id is null;

    select case when count(1)>0 then true else false end into v_mismatch_lead_p
    from flyhh_event_participants p1
    inner join flyhh_event_participants p2
    on (p1.partner_participant_id = p2.participant_id)
    where p1.participant_id = p_participant_id
    and p1.lead_p = p2.lead_p;

    select case when count(1)>0 then true else false end into v_mismatch_accommodation_p
    from flyhh_event_roommates m
    inner join flyhh_event_participants r
    on (m.roommate_id = r.participant_id)
    inner join flyhh_event_participants p
    on (m.participant_id = p.participant_id)
    where m.participant_id = p_participant_id
    and p.accommodation != r.accommodation;

    select case when count(1)>0 then true else false end into v_mismatch_level_p
    from flyhh_event_participants p1
    inner join flyhh_event_participants p2
    on (p1.partner_participant_id = p2.participant_id)
    where p1.participant_id = p_participant_id
    and p1.level != p2.level;


    -- TODO: update all roommates with an accommodation mismatch of the given participant
    -- TODO: update partner with lead/follow mismatch
    -- TODO: update partner with level mismatch

    update flyhh_event_participants set
        invalid_partner_p   = v_invalid_partner_p,
        invalid_roommates_p = v_invalid_roommates_p,
        mismatch_accomm_p   = v_mismatch_accommodation_p,
        mismatch_lead_p     = v_mismatch_lead_p,
        mismatch_level_p    = v_mismatch_level_p,
        validation_mask = 
            (case when v_invalid_partner_p then 1 else 0 end)
            + (case when v_invalid_roommates_p then 2 else 0 end)
            + (case when v_mismatch_accommodation_p then 4 else 0 end)
            + (case when v_mismatch_lead_p then 8 else 0 end)
            + (case when v_mismatch_level_p then 16 else 0 end)
    where participant_id = p_participant_id;

    return true;

end;' language 'plpgsql';


create or replace function flyhh_event_participant__new (
    integer, varchar, varchar, varchar, varchar,
	integer,
    boolean, varchar, varchar, varchar, boolean,
    integer, integer, integer, integer,
    integer, integer
) returns integer as '
DECLARE
        p_participant_id        alias for $1;

        p_email                 alias for $2;
        p_first_names           alias for $3;
        p_last_name             alias for $4;
        p_creation_ip           alias for $5;

        p_project_id            alias for $6;

        p_lead_p                alias for $7;
        p_partner_text          alias for $8;
        p_partner_name          alias for $9;
        p_partner_email         alias for $10;
        p_accepted_terms_p      alias for $11;

        p_accommodation         alias for $12;
        p_food_choice           alias for $13;
        p_bus_option            alias for $14;
        p_level                 alias for $15;

        p_payment_type          alias for $16;
        p_payment_term          alias for $17;

        v_partner_participant_id    integer;
        v_person_id                 integer;
        v_participant_id            integer;


BEGIN

        select party_id into v_person_id
        from parties where email=p_email;

        if v_person_id is null then
            select nextval(''t_acs_object_id_seq'') into v_person_id; 
            perform person__new(
                v_person_id,
                ''person'',             -- object_type
                CURRENT_TIMESTAMP,      -- creation_date
                null,                   -- creation_user
                p_creation_ip,
                p_email,
                null,
                p_first_names,
                p_last_name,
                null                    -- context_id
            );

            -- TODO: create user account

        end if;

        v_participant_id := im_biz_object__new (
            p_participant_id,
            ''flyhh_event_participant'',   -- object_type
            CURRENT_TIMESTAMP,          -- creation_date
            null,                       -- creation_user
            p_creation_ip,
            NULL                        -- context_id
        );

        select participant_id into v_partner_participant_id 
        from parties pa inner join flyhh_event_participants ep on (ep.person_id=pa.party_id)
        inner join persons p on (p.person_id = ep.person_id)
        where (email=p_partner_email or (first_names || '' '' || last_name) ilike p_partner_name)
        and project_id=p_project_id
        order by participant_id
        limit 1;

        insert into flyhh_event_participants (

            participant_id,

            person_id, 
            project_id,
            event_participant_status_id,
            event_participant_type_id,
            validation_mask,

            lead_p,
            partner_text,
            partner_name,
            partner_email,
            partner_participant_id,
            partner_person_id,
            accepted_terms_p,

            accommodation,
            food_choice,
            bus_option,
            level,

            payment_type,
            payment_term

        ) values (

            v_participant_id,

            v_person_id, 
            p_project_id,
            82500,              -- Waiting List / event_participant_status_id
            102,                -- Castle Camp / event_participant_type_id
            0,                  -- validation_mask

            p_lead_p,
            p_partner_text,
            p_partner_name,
            p_partner_email,
            v_partner_participant_id,
            (select person_id from flyhh_event_participants where participant_id=v_partner_participant_id),
            p_accepted_terms_p,

            p_accommodation,
            p_food_choice,
            p_bus_option,
            p_level,

            p_payment_type,
            p_payment_term

        );

        -- Fill-in missing info in the roommates table for this event.
        --
        -- Note: We plan to show a list of roommates which have not registered
        -- for the event so filtering by project_id ensures that we will
        -- not fill-in the info when the person registers for another event
        -- and, ditto for partner_participant_id.

        update flyhh_event_roommates set
            roommate_person_id = v_person_id,
            roommate_id = v_participant_id
        where
            roommate_email = p_email
            and project_id = p_project_id;

        -- update partner_participant_id using email or name

        update flyhh_event_participants set
            partner_participant_id = v_participant_id,
            partner_person_id = v_person_id,
            partner_mutual_p = case when participant_id = v_partner_participant_id then true else false end
        where
            ((partner_email = p_email) or (partner_name = (p_first_names || '' '' || p_last_name)))
            and project_id = p_project_id;

        -- mark partners named multiple times

        -- select case when count(1)>1 then true else false end into v_partner_double_p
        -- from flyhh_event_participants
        -- where 
        --    project_id=p_project_id
        -- and (partner_participant_id = v_participant_id 
        --        OR partner_email = p_email 
        --        OR (partner_name is not null and partner_name = p_first_names || '' '' || p_last_name));

        -- if v_partner_double_p then
        --    update flyhh_event_participants set
        --        partner_double_p = true
        --    where
        --        project_id=p_project_id
        --    and (partner_participant_id = v_participant_id 
        --            OR partner_email = p_email 
        --            OR (partner_name is not null and partner_name = p_first_names || '' '' || p_last_name));
        -- end if;

        -- Automatically transition status to pending, pending partner, pending roommates, and open
        -- for the partner and roommates but not for the given participant, see explanation below.

        -- ATTENTION: flyhh_event_participant__status_automaton needs to be invoked from
        -- the registration.tcl script for the given participant (v_participant_id) 
        -- in order to take into account the roommates that are not stored in the db at this point.

        perform flyhh_event_participant__status_automaton(v_partner_participant_id);
        perform flyhh_event_participant__status_automaton(participant_id)
        from flyhh_event_roommates
        where roommate_id=v_participant_id;

        return v_person_id;

end;' language 'plpgsql';


create or replace function flyhh_event_participant__name (integer) 
returns varchar as '
DECLARE
        p_person_id alias for $1;
        v_name  varchar;
BEGIN
        select  first_names || '' '' || last_name
        into    v_name
        from    persons
        where   person_id = p_person_id;

        return v_name;
end;' language 'plpgsql';

create or replace function flyhh_event_participant__validation_text (integer) 
returns varchar as '
declare
        p_validation_mask alias for $1;
        v_validation_text varchar;
begin

        v_validation_text := '''';

        if p_validation_mask & 1 > 0 then
            v_validation_text := v_validation_text || ''Invalid Partner'' || ''<br>'';
        end if;
        if p_validation_mask & 2 > 0 then
            v_validation_text := v_validation_text || ''Invalid Roommates'' || ''<br>'';
        end if;
        if p_validation_mask & 4 > 0 then
            v_validation_text := v_validation_text || ''Mismatch Accomm.'' || ''<br>'';
        end if;
        if p_validation_mask & 8 > 0 then
            v_validation_text := v_validation_text || ''Mismatch L/F'' || ''<br>'';
        end if;
        if p_validation_mask & 16 > 0 then
            v_validation_text := v_validation_text || ''Mismatch Level'' || ''<br>'';
        end if;
        
        return v_validation_text;

end;' language 'plpgsql';

create or replace function flyhh_event_roommate__new (
    integer, integer, varchar
) returns boolean as '
declare
    p_participant_id    alias for $1;
    p_project_id        alias for $2;
    p_roommate_email    alias for $3;
begin

    insert into flyhh_event_roommates(
        participant_id,
        project_id,
        roommate_email,
        roommate_person_id,
        roommate_id
    ) values (
        p_participant_id,
        p_project_id,
        p_roommate_email,
        (select party_id from parties where email=p_roommate_email),
        (select participant_id from flyhh_event_participants where project_id=p_project_id and person_id=(select party_id from parties where email=p_roommate_email))
    );

    return true;

end;' language 'plpgsql';

create or replace function flyhh_event_roommates__html (
    integer,varchar
) returns varchar as '
declare
    p_participant_id    alias for $1;
    p_base_url          alias for $2;

    v_count     integer;
    v_roommate  record;
    v_result    varchar;
    
begin

    v_result := '''';
    for v_roommate in 
        select r1.*, 
            first_names || '' '' || last_name as person_name,
            case when r2.participant_id is null then false else true end as mutual_p
        from 
            flyhh_event_roommates r1 left outer join persons p on (p.person_id = r1.roommate_person_id)
            left outer join flyhh_event_roommates r2 on (r2.participant_id=r1.roommate_id and r2.roommate_id=r1.participant_id)
        where 
            r1.participant_id=p_participant_id 
    loop

        if v_roommate.roommate_id is null then

            if v_roommate.roommate_person_id is null then
                v_result := v_result || ''<div style="color:red;" title="no event registration and no user account">'';
                v_result := v_result || v_roommate.roommate_email || ''</div> (no reg & no usr)'';
            else
                v_result := v_result || ''<div style="color:red;" title="no event registration">'';
                v_result := v_result || v_roommate.roommate_email || ''</div> (no reg)'';
            end if;
        else
            if v_roommate.mutual_p then
                v_result := v_result || ''<a href="'' || p_base_url || ''?participant_id='' || v_roommate.roommate_id || ''">'';
                v_result := v_result || v_roommate.person_name || ''</a>'';
            else
                v_result := v_result || ''<a style="color:green;" href="'' || p_base_url || ''?participant_id='' || v_roommate.roommate_id || ''">'';
                v_result := v_result || v_roommate.person_name || ''</a> (not mutual)'';
            end if;

        end if;

        v_result := v_result || ''<br>'';

        v_count := v_count + 1;

    end loop;

    return v_result; 

end;' language 'plpgsql';


-- We use the task_type_id referencing the project_type_id from the project which we create for the event.
-- We have one project type called „Castle Camp“ with two sub categories „SCC“ and „BCC“. 
-- When we create the event, we will have a project which then has the project type of either „SCC“ or „BCC“. 
-- Materials which can be used for both (e.g. the accommodation materials) will then have a the task_type_id 
-- of the „Castle Camp“ category, whereas the other ones have the one specific to them. 

SELECT im_category_new (102, 'Castle Camp', 'Intranet Project Type');
SELECT im_category_new (103, 'SCC', 'Intranet Project Type');
SELECT im_category_new (104, 'BCC', 'Intranet Project Type');

SELECT im_category_hierarchy_new (103, 102);
SELECT im_category_hierarchy_new (104, 102);

-- Configure when to show dynfields when using the added categories
-- INSERT INTO im_dynfield_type_attribute_map(attribute_id,object_type_id,display_mode)
-- SELECT
--        a.attribute_id,v.column1,'edit' 
-- FROM
--         (VALUES(102),(103),(104)) v,
--         im_dynfield_attributes a,
--         acs_attributes aa               
-- WHERE                                   
--         a.acs_attribute_id = aa.attribute_id
--         and aa.object_type = 'im_project'
--         and also_hard_coded_p = 'f';

-- viewing a dynfield fails if we do not set the type_category_type
UPDATE acs_object_types 
SET type_category_type='Intranet User Type' 
WHERE object_type='flyhh_event_participant';


SELECT im_category_new (9007, 'Food Choice', 'Intranet Material Type');
SELECT im_category_new (9008, 'Bus Options', 'Intranet Material Type');
SELECT im_category_new (9009, 'Levels', 'Intranet Material Type');

--- TODO: check whether it is best to modify the material_type_id or create new materials
UPDATE im_materials SET material_type_id=9007 WHERE material_id IN (33313,33314);
UPDATE im_materials SET material_type_id=9008 WHERE material_id IN (34832,34833);

SELECT im_dynfield_widget__new (
        null,                                   -- widget_id
        'im_dynfield_widget',                   -- object_type
        now(),                                  -- creation_date
        null,                                   -- creation_user
        null,                                   -- creation_ip
        null,                                   -- context_id

        'flyhh_event_participant_accommodation',      -- widget_name
        '#intranet-cust-flyhh.Accommodation#',  -- pretty_name
        '#intranet-cust-flyhh.Accommodation#',  -- pretty_plural
        10007,                                  -- storage_type_id
        'integer',                              -- acs_datatype
        'generic_sql',                          -- widget
        'integer',                              -- sql_datatype

        --- category 9002 was mispelled as "Accomodation" when it was created in the im_material_types table
        '{custom {sql {SELECT material_id,material_name FROM im_materials WHERE material_type_id=(SELECT material_type_id FROM im_material_types WHERE material_type=''Accomodation'')}}}'
);


SELECT im_dynfield_widget__new (
        null,                                   -- widget_id
        'im_dynfield_widget',                   -- object_type
        now(),                                  -- creation_date
        null,                                   -- creation_user
        null,                                   -- creation_ip
        null,                                   -- context_id

        'flyhh_event_participant_food_choice',        -- widget_name
        '#intranet-cust-flyhh.Food_Choice#',    -- pretty_name
        '#intranet-cust-flyhh.Food_Choices#',   -- pretty_plural
        10007,                                  -- storage_type_id
        'integer',                              -- acs_datatype
        'generic_sql',                          -- widget
        'integer',                              -- sql_datatype
        '{custom {sql {SELECT material_id,material_name FROM im_materials WHERE material_type_id=(SELECT material_type_id FROM im_material_types WHERE material_type=''Food Choice'')}}}'
);


SELECT im_dynfield_widget__new (
        null,                                   -- widget_id
        'im_dynfield_widget',                   -- object_type
        now(),                                  -- creation_date
        null,                                   -- creation_user
        null,                                   -- creation_ip
        null,                                   -- context_id

        'flyhh_event_participant_bus_options',        -- widget_name
        '#intranet-cust-flyhh.Bus_Options#',    -- pretty_name
        '#intranet-cust-flyhh.Bus_Options#',    -- pretty_plural
        10007,                                  -- storage_type_id
        'integer',                              -- acs_datatype
        'generic_sql',                          -- widget
        'integer',                              -- sql_datatype
        '{custom {sql {SELECT material_id,material_name FROM im_materials WHERE material_type_id=(SELECT material_type_id FROM im_material_types WHERE material_type=''Bus Options'')}}}'
);


SELECT im_dynfield_widget__new (
        null,                                   -- widget_id
        'im_dynfield_widget',                   -- object_type
        now(),                                  -- creation_date
        null,                                   -- creation_user
        null,                                   -- creation_ip
        null,                                   -- context_id

        'flyhh_event_participant_levels',             -- widget_name
        '#intranet-cust-flyhh.Levels#',         -- pretty_name
        '#intranet-cust-flyhh.Levels#',         -- pretty_plural
        10007,                                  -- storage_type_id
        'integer',                              -- acs_datatype
        'generic_sql',                          -- widget
        'integer',                              -- sql_datatype
        '{custom {sql {SELECT category_id,category FROM im_categories WHERE category_type=''Flyhh - Event Participant Level''}}}'
);



SELECT im_dynfield_attribute_new ('flyhh_event_participant', 'accommodation', 'Accommodation', 'flyhh_event_participant_accommodation', 'integer', 'f');
SELECT im_dynfield_attribute_new ('flyhh_event_participant', 'food_choice', 'Food Choice', 'flyhh_event_participant_food_choice', 'integer', 'f');
SELECT im_dynfield_attribute_new ('flyhh_event_participant', 'bus_option', 'Bus Option', 'flyhh_event_participant_bus_options', 'integer', 'f');
SELECT im_dynfield_attribute_new ('flyhh_event_participant', 'level', 'Levels', 'flyhh_event_participant_levels', 'integer', 'f');

-- dynfields with existing widgets
SELECT im_dynfield_attribute_new ('flyhh_event_participant', 'payment_type', 'Payment Method', 'category_payment_method', 'integer', 'f');
SELECT im_dynfield_attribute_new ('flyhh_event_participant', 'payment_term', 'Payment Terms', 'payment_term', 'integer', 'f');

-- ensures that dynfiels are editable and viewable by all user types
--INSERT INTO im_dynfield_type_attribute_map(attribute_id,object_type_id,display_mode)
-- SELECT 
--        a.attribute_id,c.category_id,'edit' 
-- FROM
--         im_categories c, 
--        im_dynfield_attributes a,
--        acs_attributes aa               
-- WHERE                                   
--        a.acs_attribute_id = aa.attribute_id
--        and aa.object_type = 'flyhh_event_participant'
--        and also_hard_coded_p = 'f'
--        and category_type='Intranet User Type';


-- FOR DEBUGGING/DEVELOPMENT PURPOSES ONLY
select im_project__new(
    null,           -- project_id
    'im_project',   -- object_type
    now(),          -- creation_date
    null,           -- creation_user
    null,           -- creation_ip
    null,           -- context_id
    'some project', -- project_name
    '2014_0001',    -- project_nr
    'some project', -- project_path
    null,           -- parent_id
    8720,           -- company_id (=Flying Hamburger)
    102,            -- project_type_id,
    11700           -- project_status_id (=Active)
  );


create or replace function __inline0()
returns boolean as'
declare
    v_view_id integer;
begin

    v_view_id = nextval(''im_views_seq'');

    insert into im_views(
        view_id, 
        view_name, 
        view_status_id, 
        view_type_id, 
        sort_order, 
        view_sql, 
        view_label
    ) values (
        v_view_id,
        ''flyhh_event_participants_list'',
        null,                       -- view_status_id
        1400,                       -- view_type_id / ObjectList / Intranet DynView Type
        null,                       -- sort_order
        null,                       -- view_sql
        ''Flyhh - Event Participants List'' -- view_label 
    );

    insert into im_view_columns (
        column_id, 
        view_id, 
        group_id, 
        column_name,
        variable_name,
        column_render_tcl, 
        extra_select, 
        extra_where, 
        sort_order, 
        visible_for
    ) values (
        300001, 
        v_view_id,
        NULL,
        ''Reg.ID'',
        ''participant_id'',
        ''$participant_id'',
        '''',
        '''',
        1,
        ''''
    );


    insert into im_view_columns (
        column_id, 
        view_id, 
        group_id, 
        column_name,
        variable_name,
        column_render_tcl, 
        extra_select, 
        extra_where, 
        sort_order, 
        visible_for,
        order_by_clause
    ) values (
        300002, 
        v_view_id,
        NULL,
        ''Name'',
        ''full_name'',
        ''"<a href=../registration?participant_id=$participant_id>$full_name</a><br>$email"'',
        ''first_names || '''' '''' || last_name as full_name, email, participant_id'',
        '''',
        2,
        '''',
        ''last_name,first_names,email''
    );

    insert into im_view_columns (
        column_id, 
        view_id, 
        group_id, 
        column_name,
        variable_name,
        column_render_tcl, 
        extra_select, 
        extra_where, 
        sort_order, 
        visible_for
    ) values (
        300003, 
        v_view_id,
        NULL,
        ''L/F'',
        ''lead_p'',
        ''[ad_decode $mismatch_lead_p f [set text [ad_decode $lead_p t Lead Follow]] "<font color=red>$text</font>"]'',
        '''',
        '''',
        4,
        ''''
    );


    insert into im_view_columns (
        column_id, 
        view_id, 
        group_id, 
        column_name,
        variable_name,
        column_render_tcl, 
        extra_select, 
        extra_where, 
        sort_order, 
        visible_for
    ) values (
        300004, 
        v_view_id,
        NULL,
        ''Partner'',
        ''partner_participant_id'',
        ''[ad_decode $partner_participant_id "" "<font color=red>$partner_text</font>" "<a [ad_decode $partner_mutual_p f \"style=color:green;\" \"\"] href=[export_vars -base ../registration { { participant_id $partner_participant_id } }]>$partner_person_name</a>[ad_decode $partner_email "" "<br>(match by name)" "<br>($partner_email)"][ad_decode $partner_mutual_p f "<br>(not mutual)" ""]"]'',
        ''partner_email'',
        '''',
        5,
        ''''
    );




    insert into im_view_columns (
        column_id, 
        view_id, 
        group_id, 
        column_name,
        variable_name,
        column_render_tcl, 
        extra_select, 
        extra_where, 
        sort_order, 
        visible_for
    ) values (
        300005,
        v_view_id,
        NULL,
        ''Accomm.'',
        ''accommodation'',
        ''$accommodation'',
        ''im_name_from_id(accommodation) as accommodation'',
        '''',
        6,
        ''''
    );


    insert into im_view_columns (
        column_id, 
        view_id, 
        group_id, 
        column_name,
        variable_name,
        column_render_tcl, 
        extra_select, 
        extra_where, 
        sort_order, 
        visible_for
    ) values (
        300006,
        v_view_id,
        NULL,
        ''Food Choice'',
        ''food_choice'',
        ''$food_choice'',
        ''im_name_from_id(food_choice) as food_choice'',
        '''',
        7,
        ''''
    );


    insert into im_view_columns (
        column_id, 
        view_id, 
        group_id, 
        column_name,
        variable_name,
        column_render_tcl, 
        extra_select, 
        extra_where, 
        sort_order, 
        visible_for
    ) values (
        300007,
        v_view_id,
        NULL,
        ''Bus Option'',
        ''bus_option'',
        ''$bus_option'',
        ''im_name_from_id(bus_option) as bus_option'',
        '''',
        8,
        ''''
    );


    insert into im_view_columns (
        column_id, 
        view_id, 
        group_id, 
        column_name,
        variable_name,
        column_render_tcl, 
        extra_select, 
        extra_where, 
        sort_order, 
        visible_for
    ) values (
        300008,
        v_view_id,
        NULL,
        ''Level'',
        ''level'',
        ''[ad_decode $mismatch_level_p f $level "<font color=red>$level</font>"]'',
        ''im_name_from_id(level) as level'',
        '''',
        9,
        ''''
    );



    insert into im_view_columns (
        column_id, 
        view_id, 
        group_id, 
        column_name,
        variable_name,
        column_render_tcl, 
        extra_select, 
        extra_where, 
        sort_order, 
        visible_for
    ) values (
        300009,
        v_view_id,
        NULL,
        ''Payment Type'',
        ''payment_type'',
        ''$payment_type'',
        ''im_name_from_id(payment_type) as payment_type'',
        '''',
        10,
        ''''
    );


    insert into im_view_columns (
        column_id, 
        view_id, 
        group_id, 
        column_name,
        variable_name,
        column_render_tcl, 
        extra_select, 
        extra_where, 
        sort_order, 
        visible_for
    ) values (
        300010,
        v_view_id,
        NULL,
        ''Payment Term'',
        ''payment_term'',
        ''$payment_term'',
        ''im_name_from_id(payment_term) as payment_term'',
        '''',
        11,
        ''''
    );


    insert into im_view_columns (
        column_id, 
        view_id, 
        group_id, 
        column_name,
        variable_name,
        column_render_tcl, 
        extra_select, 
        extra_where, 
        sort_order, 
        visible_for,
        datatype
    ) values (
        300011,
        v_view_id,
        NULL,
        ''Roommate(s)'',
        ''roommates'',
        ''$roommates_html'',
        ''flyhh_event_roommates__html(participant_id,''''../registration'''') as roommates_html'',
        '''',
        12,
        '''',
        ''category_pretty''
    );



    insert into im_view_columns (
        column_id, 
        view_id, 
        group_id, 
        column_name,
        variable_name,
        column_render_tcl, 
        extra_select, 
        extra_where, 
        sort_order, 
        visible_for,
        datatype
    ) values (
        300012,
        v_view_id,
        NULL,
        ''Validation'',
        ''validation_mask'',
        ''$validation_text'',
        ''flyhh_event_participant__validation_text(validation_mask) as validation_text'',
        '''',
        13,
        '''',
        ''''
    );

    insert into im_view_columns (
        column_id, 
        view_id, 
        group_id, 
        column_name,
        variable_name,
        column_render_tcl, 
        extra_select, 
        extra_where, 
        sort_order, 
        visible_for,
        datatype
    ) values (
        300013,
        v_view_id,
        NULL,
        ''Status'',
        ''event_participant_status_id'',
        ''[im_category_select "Flyhh - Event Registration Status" "event_participant_status_id.$participant_id" $event_participant_status_id]'',
        ''participant_id,event_participant_status_id'',
        '''',
        14,
        '''',
        ''category_pretty''
    );


    return true;

end' language 'plpgsql';

select __inline0();
drop function __inline0();

-- Category IDs 82000-82999 reserved for Events

--
-- Flyhh - Event Registration Status
-- (status Options in the normal flow of things)
--

-- if the participant registers he is put onto a waiting list
SELECT im_category_new (82500, 'Waiting List', 'Flyhh - Event Registration Status');

-- this is the status we provide if the participant is accepted from our side into the camp
SELECT im_category_new (82501, 'Confirmed', 'Flyhh - Event Registration Status');

-- this is the status once the participant clicks the link to get the payment information
SELECT im_category_new (82502, 'Pending Payment', 'Flyhh - Event Registration Status');

-- this is the status once the participant has partially paid
SELECT im_category_new (82503, 'Partially Paid', 'Flyhh - Event Registration Status');

-- this is the status once the participant has fully paid
SELECT im_category_new (82504, 'Registered', 'Flyhh - Event Registration Status');

-- this is the status if the system kicks the partipanct out or we cancel the participant. 
-- This only happens if the participant is not registered yet
SELECT im_category_new (82505, 'Refused', 'Flyhh - Event Registration Status');

-- this is if the participant decided not to come anymore
SELECT im_category_new (82506, 'Cancelled', 'Flyhh - Event Registration Status');

--
-- Flyhh - Event Participant Level
--

SELECT im_category_new (82550, 'Beginner', 'Flyhh - Event Participant Level');
SELECT im_category_new (82551, 'Intermediate', 'Flyhh - Event Participant Level');
SELECT im_category_new (82552, 'Advanced', 'Flyhh - Event Participant Level');

