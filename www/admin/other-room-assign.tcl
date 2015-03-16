ad_page_contract {

} {
    project_id:integer,notnull
    {room_p "0"}
}

db_1row project_name "select project_name,event_id from im_projects p, flyhh_events e where p.project_id = :project_id and e.project_id = p.project_id"
set page_title [_ intranet-cust-flyhh.other_room_assign]
set return_url [export_vars -base "rooms-list" -url {{filter_project_id $project_id}}]

# Append the project members which are not participants

set occupants [list]
if {$room_p} {
    set extra_where_clause ""
} else {
    set extra_where_clause "and room_id is null"
}
set sql "select	p.person_id, room_id
        from	 persons p, acs_rels r
        left outer join flyhh_event_room_occupants ro on (ro.person_id = r.object_id_two and ro.project_id = r.object_id_one)
        where   r.object_id_one=:project_id and
                r.rel_type = 'im_biz_object_member' and
                r.object_id_two not in (
                    -- Exclude deleted or disabled users
                    select	m.member_id
                    from	group_member_map m,
                        membership_rels mr
                    where	m.group_id = acs__magic_object_id('registered_users') and
                        m.rel_id = mr.rel_id and
                        m.container_id = m.group_id and
                        mr.member_state != 'approved'
                ) and r.object_id_two not in (select person_id from flyhh_event_participants where project_id = :project_id)
                and p.person_id = r.object_id_two
                $extra_where_clause
                order by im_name_from_id(object_id_two)
        "

db_foreach person $sql {
    ds_comment "$person_id"
    if {$room_id eq ""} {
        lappend occupants [list "[person::name -person_id $person_id]" $person_id]
    } else {
        lappend occupants [list "[person::name -person_id $person_id] -- [flyhh_event_room_description -room_id $room_id]" $person_id]    
    }

}
        

set room_options [list [list "" ""]]
db_foreach rooms "
    select room_name,e.room_id, office_name, sleeping_spots, material_name,
    (select count(*) from flyhh_event_room_occupants ro where ro.room_id = e.room_id and p.project_id = ro.project_id) as taken_spots
    from flyhh_event_rooms e
    inner join im_offices o on (e.room_office_id = o.office_id)
    inner join im_projects p on (o.company_id = p.company_id)
    inner join im_materials m on (e.room_material_id = m.material_id)
    where p.project_id = :project_id
" {
    if {$taken_spots < $sleeping_spots} {
        set free_spots [expr $sleeping_spots - $taken_spots]
        lappend room_options [list "$room_name ($office_name) - $material_name - $free_spots" $room_id]
    }
}

set form_id "assign_room"
set action_url "other-room-assign"
ad_form \
    -name $form_id \
    -action $action_url \
    -export [list project_id return_url] \
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
    
ad_form \
    -name "flyhh_event_room_filter" \
    -action "other-room-assign" \
    -mode edit \
    -method GET \
    -export {project_id} \
    -form {
        {room_p:text(select),optional
            {label {[::flyhh::mc room_p "Room Assigned"]}}
            {options {{No 0} {Yes 1} }}
        }
    } 
    
    
    # Filter (possibly) later on
    # Compile and execute the formtemplate if advanced filtering is enabled.
    eval [template::adp_compile -string {<formtemplate id="flyhh_event_room_filter" style="tiny-plain-po"></formtemplate>}]
    set filter_html $__adp_output
    
    # Left Navbar is the filter/select part of the left bar
    set left_navbar_html "
        <div class='filter-block'>
                <div class='filter-title'>
                   [::flyhh::mc Filter_Rooms "Filter Rooms"]
                </div>
                    $filter_html
              </div>
          <hr/>
    "
