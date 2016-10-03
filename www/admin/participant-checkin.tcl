ad_page_contract {

    @author malte.sussdorff@cognovis.de
    @creation-date 2015-03-11
    @last-modified 2015-03-11

    Display the list of rooms available in the system
    
} {
    project_id
}

set show_context_help_p 0
set filter_admin_html ""
set page_title "[::flyhh::mc Participants "Participants"]"
set context_bar [ad_context_bar $page_title]

set list_id "checkin_list"
set multirow "checkin"

set participant_status_ids [list 82502 82503 82504 82507]

set sql "select im_name_from_id(ep.person_id) as participant,course,im_category_from_id(level) as level, im_category_from_id(event_participant_status_id) as status,food_choice, (select sum(p.amount) from im_payments p where p.cost_id = ep.invoice_id) as paid_amount, room_name, im_name_from_id(room_office_id) as room_location from flyhh_event_participants ep, flyhh_event_room_occupants ro, flyhh_event_rooms er where er.room_id = ro.room_id and ro.person_id = ep.person_id and ep.project_id = ro.project_id and ep.project_id = :project_id and ep.event_participant_status_id in ([template::util::tcl_to_sql_list $participant_status_ids])"

db_multirow -extend {checkin_radio open_amount room} checkin $multirow $sql {
    if {$status == "Registered"} {
	set open_amount ""
    } else {
	set open_amount "OPEN"
    }
    set room "$room_name ($room_location)"

    set course [db_string course "select material_name from im_materials where material_id = :course"]
    set food_choice [db_string food_choice "select material_name from im_materials where material_id = :food_choice"]
    set checkin_radio "<center><input type='checkbox'></input></center>"
}

template::multirow sort $multirow -nocase participant 

template::list::create \
    -name checkin_list \
    -multirow $multirow \
    -elements {
        participant {
            label {[::flyhh::mc Participant "Participant"]}
        }
	course {
            label {[::flyhh::mc Course "Course"]}
	}
	level {
            label {[::flyhh::mc Level "Level"]}
	}
        room {
            label {[::flyhh::mc room "Room"]}
        }
	food_choice {
            label {[::flyhh::mc Food_Choice "Food Choice"]}
	}
	open_amount {
	    label {[::flyhh::mc Open_Amount "Open Amount"]}
	}
	status {
	    label {[::flyhh::mc Status "Status"]}
	}
	checkin_radio {
	    label {[::flyhh::mc Checkin "Checkin"]}
            display_template {
                @checkin.checkin_radio;noquote@
            }
	}
    }
