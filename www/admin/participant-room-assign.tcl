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

    if {[db_0or1row occupant_info "select person_id,accommodation, material_name as acc_name from flyhh_event_participants ep, im_materials m where participant_id = :occupant_id and ep.accommodation = m.material_id"]} {
	if {[lsearch $room_types $accommodation]<0} {
	    lappend room_types $accommodation
	}
	lappend occupants [list "[person::name -person_id $person_id] ($acc_name)" $person_id]
    }
}

ds_comment "$room_types"
set room_options [list [list "" ""]]
db_foreach rooms "
    select room_name,e.room_id, office_name, sleeping_spots, material_name,
    coalesce((select count(*) from flyhh_event_room_occupants ro where ro.room_id = e.room_id and p.project_id = ro.project_id),0) as taken_spots
    from flyhh_event_rooms e
    inner join im_offices o on (e.room_office_id = o.office_id)
    inner join im_projects p on (o.company_id = p.company_id)
    inner join im_materials m on (e.room_material_id = m.material_id)
    where p.project_id = :project_id
    and e.room_material_id in ([template::util::tcl_to_sql_list $room_types])
" {
    ds_comment "$taken_spots :: $sleeping_spots"
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
        {person_ids:text(checkbox),multiple,optional
            {label {[::flyhh::mc Occupants "Occupants"]}}
            {options $occupants}
            {html {checked 1}}
        }
        {room_id:text(select),optional
            {label {[::flyhh::mc Room "Room"]}}
            {options $room_options}
        }
        {note:richtext(richtext),optional
            {label {[::flyhh::mc note "Note"]}}
            {html {cols 40} {rows 8} }
        }
    } -validate {
        {room_id
            {[llength $person_ids]<=[db_string open_spots "select sleeping_spots - (select count(*) from flyhh_event_room_occupants ro where ro.room_id = r.room_id and ro.project_id = :project_id and person_id not in ([template::util::tcl_to_sql_list $person_ids])) as taken_spots from flyhh_event_rooms r where room_id = :room_id" -default 0]}
            {"The room does not have enough vacancies to accommodate all selected occupants ([llength $person_ids])"}
        }
    } -on_submit {
            db_dml delete_occupants "delete from flyhh_event_room_occupants where project_id = :project_id and person_id in ([template::util::tcl_to_sql_list $person_ids])"
            foreach person_id $person_ids {
                db_dml insert_occupant "insert into flyhh_event_room_occupants (room_id, person_id,project_id,note) values (:room_id, :person_id, :project_id,:note) "
            }
            ad_returnredirect $return_url
    }
