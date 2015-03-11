ad_page_contract {

} {
    project_id:integer,notnull
    participant_ids:notnull
    return_url:trim,notnull
}

# Find the roommates to the participant_ids so we can fill the occupant_ids

set occ_participant_ids [list]

foreach participant_id $participant_ids {
    lappend occ_participant_ids $participant_id
    db_foreach roommate "select roommate_id from flyhh_event_roommates where participant_id = :participant_id" {
        lappend occ_participant_ids $roommate_id
    }
}

set occ_participant_ids [lsort -unique $occ_participant_ids] 

set occupants [list]
set room_types [list]
foreach occupant_id $occ_participant_ids {
    db_1row occupant_info "select person_id,accommodation, material_name as acc_name from flyhh_event_participants ep, im_materials m where participant_id = :occupant_id and ep.accommodation = m.material_id"
    if {[lsearch $room_types $accommodation]<0} {
        lappend room_types $accommodation
    }
    lappend occupants [list "[person::name -person_id $person_id] ($acc_name)" $occupant_id]
}

set room_options [list [list "" ""]]
db_foreach rooms "
    select room_name,e.room_id, office_name, sleeping_spots, material_name,
    (select count(*) from flyhh_event_participants ep where ep.room_id = e.room_id and p.project_id = ep.project_id) as taken_spots
    from flyhh_event_rooms e, im_offices o, im_projects p, im_materials m
    where e.room_office_id = o.office_id
    and o.company_id = p.company_id
    and e.room_material_id = m.material_id
    and p.project_id = :project_id
    and e.room_material_id in ([template::util::tcl_to_sql_list $room_types])
" {
    if {$taken_spots < $sleeping_spots} {
        set free_spots [expr $sleeping_spots - $taken_spots]
        lappend room_options [list "$room_name ($office_name) - $material_name - $free_spots" $room_id]
    }
}

set form_id "assign_room"
set action_url "participant-room-assign"
ad_form \
    -name $form_id \
    -action $action_url \
    -export [list project_id return_url participant_ids] \
    -form {
        {occupant_ids:text(checkbox),multiple,optional
            {label {[::flyhh::mc Occupants "Occupants"]}}
            {options $occupants}
            {html {checked 1}}
        }
        {room_id:text(select),optional
            {label {[::flyhh::mc Room "Room"]}}
            {options $room_options}
        }
    } -on_submit {
            db_dml update_room "update flyhh_event_participants set room_id = :room_id where participant_id in ([template::util::tcl_to_sql_list $occupant_ids])"
            ad_returnredirect $return_url
    }