if {![info exists participant_id]} {
    ad_page_contract {
        @author malte.sussdorff@cognovis.de
    } {
	   participant_id:integer
    }
}

if {![info exists return_url] || "" == $return_url} { set return_url [im_url_with_query] }
set user_id [ad_maybe_redirect_for_registration]
set new_roommate_url [export_vars -base "/flyhh/roommate-new" {participant_id return_url}]


# ----------------------------------------------------
# Create a "multirow" to show the results

multirow create roomates roommate_name roommate_url room_name room_url

set roommates_sql "
	select *
	from	   flyhh_event_roommates er
	inner join flyhh_event_participants ep on (ep.participant_id = er.participant_id)
	where  ep.participant_id = :participant_id
    "

set room_id [db_string room_id "select room_id from flyhh_event_room_occupants ro, flyhh_event_participants ep where ep.person_id = ro.person_id and ep.project_id = ro.project_id and ep.participant_id = :participant_id" -default ""]

db_multirow -extend {roommate_status roommate_url room_url room_name} roommates roommates_query $roommates_sql {
    set status_list [list]

    if {$roommate_person_id ne ""} {
        db_1row participant_info "select participant_id as roommate_participant_id, room_id as roommate_room_id from flyhh_event_participants ep 
        left outer join flyhh_event_room_occupants ro on (ep.person_id = ro.person_id and ep.project_id = ro.project_id) where ep.project_id = :project_id and ep.person_id = :roommate_person_id"
    }
    if {![exists_and_not_null roommate_participant_id]} {
        set roommate_url ""
    } else {
        set roommate_url [export_vars -base "/flyhh/admin/registration" -url {project_id {participant_id $roommate_participant_id}}]
        if {![db_string roommate_mutual_p "select 1 from flyhh_event_roommates where participant_id = :roommate_participant_id and roommate_person_id = :person_id" -default 0]} {
            lappend status_list [::flyhh::mc Roommate_not_mutual "Roommate not mutual"]
        }
    }
    if {![exists_and_not_null roommate_room_id]} {
        set room_url ""
        	set room_name ""
    } else {
        	set room_name [db_string room "select room_name from flyhh_event_rooms where room_id = :roommate_room_id" -default ""]
        set room_url [export_vars -base "/flyhh/admin/room-one" -url {{room_id $roommate_room_id} {filter_project_id $project_id}}]
        if {$room_id ne $roommate_room_id} {
            lappend status_list [::flyhh::mc Different_Rooms "Different Rooms"]
        }
    }
    
    if {$status_list ne ""} {
        set roommate_status "<ul><li>"
        append roommate_status [join $status_list "</li><li>"]
        append roommate_status "</li></ul>"
    } else {
        set roommate_status ""
    }

    
}
