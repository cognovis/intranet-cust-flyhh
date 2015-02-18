select acs_log__debug('/packages/intranet-cust-flyhh/sql/postgresql/upgrade/upgrade-4.1.0.0.2-4.1.0.0.3.sql','');

-- Component for projects
SELECT im_component_plugin__new (
        null,                           -- plugin_id
        'acs_object',                   -- object_type
        now(),                          -- creation_date
        null,                           -- creation_user
        null,                           -- creation_ip
        null,                           -- context_id
        'Intranet Mail Participant Component',        -- plugin_name
        'intranet-mail',                  -- package_name
        'right',                        -- location
        '/flyhh/admin/registration',      -- page_url
        null,                           -- view_name
        12,                             -- sort_order
        'im_mail_object_component -context_id $project_id -return_url $return_url -mail_url $mail_url -recipient $person_id'
);
