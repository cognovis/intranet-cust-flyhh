select acs_log__debug('/packages/intranet-cust-flyhh/sql/postgresql/upgrade/upgrade-4.1.0.0.3-4.1.0.0.4.sql','');

-- Component for roommates
SELECT im_component_plugin__new (
        null,                           -- plugin_id
        'acs_object',                   -- object_type
        now(),                          -- creation_date
        null,                           -- creation_user
        null,                           -- creation_ip
        null,                           -- context_id
        'Intranet Roommate Component',        -- plugin_name
        'intranet-cust-flyhh',                  -- package_name
        'right',                        -- location
        '/flyhh/admin/registration',      -- page_url
        null,                           -- view_name
        12,                             -- sort_order
        'flyhh_roommate_component -return_url $return_url -participant_id $participant_id'
);

-- Room information

select acs_object_type__create_type (
        'flyhh_event_room',      -- object_type
        'Flyhh - Event Room',    -- pretty_name
        'Flyhh - Event Rooms',   -- pretty_plural
        'im_biz_object',                -- supertype
        'flyhh_event_rooms',     -- table_name
        'room_id',      		        -- id_column
        'flyhh_event_room', 	    -- pl/pgsql package_name
        'f',                            -- abstract_p
        null,                           -- type_extension_table
        'flyhh_event_room__name'    -- name_method
);

insert into acs_object_type_tables (object_type,table_name,id_column)
values ('flyhh_event_room', 'flyhh_event_roomss', 'room_id');

update acs_object_types set
    status_type_table = 'flyhh_event_rooms',
    status_column = 'event_room_status_id',
    type_column = 'event_room_type_id'
where object_type = 'flyhh_event_room';

create table flyhh_event_rooms (
    room_id             integer not null
                        constraint flyhh_event_rooms_pk
                        primary key,
    room_name           varchar(100) not null,
    room_material_id    integer not null
                        constraint flyhh_event_rooms_material_fk
                        references im_materials(material_id),
    sleeping_spots      integer not null,
    single_beds         integer,
    double_beds         integer,
    additional_beds     integer,
    toilet_p            boolean,
    bath_p              boolean,
    description         text
);

CREATE OR REPLACE FUNCTION inline_0 ()
RETURNS INTEGER AS
$$
declare
    v_count integer;
begin
    select count(*) into v_count
    from	 user_tab_columns 
    where lower(table_name) = 'flyhh_event_participants'
    and lower(column_name) = 'room_id';
    IF 0 != v_count THEN return 0; END IF;

    alter table flyhh_event_participants
    add column room_id            integer
    constraint flyhh_event_participants_room_id_fk
    references flyhh_event_rooms(room_id);

    return 1;

end;
$$ LANGUAGE 'plpgsql';

SELECT inline_0 ();
DROP FUNCTION inline_0 ();