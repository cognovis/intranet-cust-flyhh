select acs_log__debug('/packages/intranet-cust-flyhh/sql/postgresql/upgrade/upgrade-4.1.0.1.0-4.1.0.1.1.sql','');

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
    
select case when (v_partner_mutual_p = false) then true else false end into v_invalid_partner_p
    from flyhh_event_participants
    where participant_id = p_participant_id;

select case when (partner_participant_id is null) then false else v_invalid_partner_p end into v_invalid_partner_p
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