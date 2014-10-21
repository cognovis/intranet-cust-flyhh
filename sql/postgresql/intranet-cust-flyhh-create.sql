--- @author Neophytos Demetriou
--- @creation-date 2014-10-15
--- @last-modified 2014-10-20

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
    person_id			integer
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
        select  first_names || ' ' || last_name
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

--- Configure when to show dynfields when using the added categories
INSERT INTO im_dynfield_type_attribute_map(attribute_id,object_type_id,display_mode)
SELECT
        a.attribute_id,v.column1,'edit' 
FROM
        (VALUES(102),(103),(104)) v,
        im_dynfield_attributes a,
        acs_attributes aa               
WHERE                                   
        a.acs_attribute_id = aa.attribute_id
        and aa.object_type = 'im_project'
        and also_hard_coded_p = 'f';

--- viewing a dynfield fails if we do not set the type_category_type
UPDATE acs_object_types 
SET type_category_type='Intranet User Type' 
WHERE object_type='im_event_participant';


--- ensures that dynfiels are editable and viewable by all user types
INSERT INTO im_dynfield_type_attribute_map(attribute_id,object_type_id,display_mode)
SELECT 
        a.attribute_id,c.category_id,'edit' 
FROM
        im_categories c, 
        im_dynfield_attributes a,
        acs_attributes aa               
WHERE                                   
        a.acs_attribute_id = aa.attribute_id
        and aa.object_type = 'im_event_participant'
        and also_hard_coded_p = 'f'
        and category_type='Intranet User Type';


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

        'event_participant_accommodation',      -- widget_name
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

        'event_participant_food_choice',        -- widget_name
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

        'event_participant_bus_options',        -- widget_name
        '#intranet-cust-flyhh.Bus_Options#',    -- pretty_name
        '#intranet-cust-flyhh.Bus_Options#',    -- pretty_plural
        10007,                                  -- storage_type_id
        'integer',                              -- acs_datatype
        'generic_sql',                          -- widget
        'integer',                              -- sql_datatype
        '{custom {sql {SELECT material_id,material_name FROM im_materials WHERE material_type_id=(SELECT material_type_id FROM im_material_types WHERE material_type=''Bus Options'')}}}'
);

ALTER TABLE im_event_participants ADD accommodation integer REFERENCES im_materials(material_id);
ALTER TABLE im_event_participants ADD food_choice integer REFERENCES im_materials(material_id);
ALTER TABLE im_event_participants ADD bus_options integer REFERENCES im_materials(material_id);
--- ALTER TABLE im_event_participants ADD discounts integer REFERENCES im_materials(material_id);
--- ALTER TABLE im_event_participants ADD other integer REFERENCES im_materials(material_id);
--- ALTER TABLE im_event_participants ADD course_income integer REFERENCES im_materials(material_id);
ALTER TABLE im_event_participants ADD payment_type integer REFERENCES im_categories(category_id);
ALTER TABLE im_event_participants ADD payment_term integer REFERENCES im_categories(category_id);

SELECT im_dynfield_attribute_new ('im_event_participant', 'accommodation', 'Accommodation', 'event_participant_accommodation', 'integer', 'f');
SELECT im_dynfield_attribute_new ('im_event_participant', 'food_choice', 'Food Choice', 'event_participant_food_choice', 'integer', 'f');
SELECT im_dynfield_attribute_new ('im_event_participant', 'bus_options', 'Bus Options', 'event_participant_bus_options', 'integer', 'f');

--- fixed fields
--- lead_p
--- partner_email
--- roommates
--- accept_terms_p

--- dynfields with existing widgets
SELECT im_dynfield_attribute_new ('im_event_participant', 'payment_type', 'Payment Method', 'category_payment_method', 'integer', 'f');
SELECT im_dynfield_attribute_new ('im_event_participant', 'payment_term', 'Payment Terms', 'payment_term', 'integer', 'f');

