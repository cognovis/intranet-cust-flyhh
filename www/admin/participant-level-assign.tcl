ad_page_contract {

} {
    project_id:integer,notnull
    participant_ids:notnull
    return_url:trim,notnull
}

# Find the room types and prepare the list of occupants we are talking about
foreach participant_id $participant_ids {

    db_foreach participant_info "select person_id,im_name_from_id(level) as level_name,participant_id from flyhh_event_participants ep where participant_id = :participant_id 
union select person_id,im_name_from_id(level) as level_name,participant_id from flyhh_event_participants ep where partner_participant_id = :participant_id" {
    ds_comment "Level:: $level_name"
    	lappend participants [list "[person::name -person_id $person_id] ($level_name)" $participant_id]
    }
}


set form_id "assign_level"
set action_url "participant-level-assign"
ad_form \
    -name $form_id \
    -action $action_url \
    -export [list project_id return_url participant_ids] \
    -form {
        {participants_ids:text(checkbox),multiple,optional
            {label {[::flyhh::mc Participants "Participants"]}}
            {options $participants}
            {html {checked 1}}
        }
        {level:text(im_category_tree)
            {label {[::flyhh::mc Level "Level"]}} 
            {custom {category_type "Flyhh - Event Participant Level" translate_p 1 package_key "intranet-cust-flyhh"}}
	}
    } -validate {
    } -on_submit {
            foreach participant_id $participants_ids {
                db_dml update_registration "update flyhh_event_participants set level = :level where participant_id = :participant_id"
            }
            ad_returnredirect $return_url
    }
