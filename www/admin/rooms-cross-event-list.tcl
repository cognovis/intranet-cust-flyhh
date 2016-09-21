ad_page_contract {

    @author malte.sussdorff@cognovis.de
    @creation-date 2015-03-11
    @last-modified 2015-03-11

    Display the list of rooms available in the system
    
} {
    {filter_project_id ""}
    {participant_filter "all"}
    room_material_id:integer,optional
    room_office_id:integer,optional
    {orderby ""}
}

set show_context_help_p 0
set filter_admin_html ""
set page_title "[::flyhh::mc Rooms "Rooms"]"
set context_bar [ad_context_bar $page_title]

set list_id "rooms_list"
set multirow "rooms"

template::list::create \
    -name rooms_list \
    -multirow $multirow \
    -elements {
        participant {
            label {[::flyhh::mc Participant "Participant"]}
        }
        bcc_room {
            label {[::flyhh::mc bcc_room "BCC Room"]}
            display_template {
                @rooms.bcc_room;noquote@
            }
        }
        scc_room {
            label {[::flyhh::mc bcc_room "SCC Room"]}
            display_template {
                @rooms.scc_room;noquote@
            }
        }
    }

set bcc_project_id [db_string bcc_project "select project_id from im_projects where project_status_id = 76 and project_cost_center_id = 12356"]
set scc_project_id [db_string scc_project "select project_id from im_projects where project_status_id = 76 and project_cost_center_id = 34915"]

set sql "select * from (select count(person_id) as count, person_id, im_name_from_id(person_id) as participant from flyhh_event_room_occupants where project_id in ($bcc_project_id, $scc_project_id) group by person_id) as foo where count >1"


db_multirow -extend {bcc_room scc_room} rooms $multirow $sql {
    # Get the BCC Room

    db_1row bcc_info "select r.room_id, r.room_name as bcc_room_name, m.material_name from flyhh_event_room_occupants ro, flyhh_event_rooms r, im_materials m where ro.person_id = :person_id and ro.project_id = :bcc_project_id and r.room_id = ro.room_id and r.room_material_id = m.material_id"
    
    set bcc_room "<center><bold>$bcc_room_name</bold><br />($material_name)</center>"
    
    # scc
    db_1row scc_info "select r.room_id, r.room_name as scc_room_name, m.material_name from flyhh_event_room_occupants ro, flyhh_event_rooms r, im_materials m where ro.person_id = :person_id and ro.project_id = :scc_project_id and r.room_id = ro.room_id and r.room_material_id = m.material_id"
    
    if {$scc_room_name ne $bcc_room_name} {
	set scc_room_name "<font color = 'red'>$scc_room_name</font>"
    }
    set scc_room "<center><bold>$scc_room_name</bold><br />($material_name)</center>"
    
}
