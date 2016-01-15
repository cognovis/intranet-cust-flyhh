select acs_log__debug('/packages/intranet-cust-flyhh/sql/postgresql/upgrade/upgrade-4.1.0.0.10-4.1.0.0.11.sql','');

-- Component for roommates
SELECT im_component_plugin__new (
        null,                           -- plugin_id
        'acs_object',                   -- object_type
        now(),                          -- creation_date
        null,                           -- creation_user
        null,                           -- creation_ip
        null,                           -- context_id
        'FlyHH Level Component',        -- plugin_name
        'intranet-cust-flyhh',                  -- package_name
        'left',                        -- location
        '/flyhh/admin/registration',      -- page_url
        null,                           -- view_name
        12,                             -- sort_order
        'flyhh_level_component -participant_id $participant_id'
);

CREATE OR REPLACE FUNCTION inline_0 ()
RETURNS integer AS '
DECLARE

    v_object_id	integer;
    v_employees	integer;
    v_poadmins	integer;

BEGIN
    SELECT group_id INTO v_employees FROM groups where group_name = ''P/O Admins'';

    SELECT group_id INTO v_poadmins FROM groups where group_name = ''Employees'';


    -- Intranet Mail Ticket Component
    SELECT plugin_id INTO v_object_id FROM im_component_plugins WHERE plugin_name = ''FlyHH Level Component'' AND page_url = ''/flyhh/admin/registration'';

    PERFORM im_grant_permission(v_object_id,v_employees,''read'');
    PERFORM im_grant_permission(v_object_id,v_poadmins,''read'');

    RETURN 0;

END;' language 'plpgsql';

SELECT inline_0 ();
DROP FUNCTION inline_0 ();