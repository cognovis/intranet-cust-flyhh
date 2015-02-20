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

update im_view_columns set column_render_tcl = '$partner_html', extra_select = '', order_by_clause = '' where column_id = 300004;
update im_view_columns set column_render_tcl = '"<a href=registration?project_id=$project_id&participant_id=$participant_id>$participant_person_name</a><br /><a href=''/intranet/companies/view?company_id=$company_id''>$email</a>"' where column_id = '300002';

create or replace function flyhh_event_participant__update (
    p_participant_id        integer,
    p_email                 varchar,
    p_first_names           varchar,
    p_last_name             varchar,
    p_creation_ip           varchar,
    p_project_id            integer,
    p_lead_p                boolean,
    p_partner_text          varchar,
    p_partner_name          varchar,
    p_partner_email         varchar,
    p_partner_person_id     integer,
    p_partner_participant_id integer,
    p_accepted_terms_p      boolean,
    p_course                integer,
    p_accommodation         integer,
    p_food_choice           integer,
    p_bus_option            integer,
    p_level                 integer,
    p_payment_type          integer,
    p_payment_term          integer
) returns boolean as
$$
declare

    v_person_id                 integer;

begin

    select person_id into v_person_id
    from flyhh_event_participants
    where participant_id = p_participant_id;

    update persons set
        first_names = p_first_names,
        last_name = p_last_name
    where
        person_id = v_person_id;

    update flyhh_event_participants set
        lead_p              = p_lead_p,
        partner_text        = p_partner_text,
        partner_name        = p_partner_name,
        partner_email       = p_partner_email,
        partner_person_id   = p_partner_person_id,
        accepted_terms_p    = p_accepted_terms_p,
        course              = p_course,
        accommodation       = p_accommodation,
        food_choice         = p_food_choice,
        bus_option          = p_bus_option,
        level               = p_level,
        payment_type        = p_payment_type,
        payment_term        = p_payment_term,
        partner_participant_id = p_partner_participant_id
    where participant_id=p_participant_id;

    return true;

end;
$$ language 'plpgsql';

create or replace function flyhh_event_participant__status_automaton_helper (
    p_participant_id        integer
) returns boolean as
$$
declare

    v_invalid_both_p                boolean;
    v_invalid_partner_p             boolean;
    v_invalid_roommates_p           boolean;
    v_mismatch_lead_p               boolean;
    v_mismatch_accommodation_p      boolean;
    v_mismatch_level_p              boolean;
    v_partner_mutual_p              boolean;
    v_category                      varchar;

begin

    -- Update the mutual_partner information
    select case when (p_participant_id = (select partner_participant_id from flyhh_event_participants p where participant_id = e.partner_participant_id)) then true else false end into v_partner_mutual_p 
    from flyhh_event_participants e where participant_id = p_participant_id;
    
    -- Update the other partner in case we switched to somebody else
    if v_partner_mutual_p = false then 
        update flyhh_event_participants set partner_mutual_p = false where partner_participant_id = p_participant_id;
    end if;
    
    select case when (partner_participant_id is null OR NOT(partner_mutual_p)) then true else false end into v_invalid_partner_p
    from flyhh_event_participants
    where participant_id = p_participant_id;

    select case when count(1)>0 then true else false end into v_invalid_roommates_p
    from flyhh_event_roommates
    where participant_id = p_participant_id
    and (roommate_id is null or not(roommate_mutual_p));

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
        partner_mutual_p    = v_partner_mutual_p,
        validation_mask = 
            (case when v_invalid_partner_p then 1 else 0 end)
            + (case when v_invalid_roommates_p then 2 else 0 end)
            + (case when v_mismatch_accommodation_p then 4 else 0 end)
            + (case when v_mismatch_lead_p then 8 else 0 end)
            + (case when v_mismatch_level_p then 16 else 0 end)
    where participant_id = p_participant_id;

    return true;

end;
$$ language 'plpgsql';

update im_companies set vat_type_id = 42000;