ad_page_contract {

    event_stats.tcl
    @date 2015-03-09
}

db_1row event_info "select project_cost_center_id, p.project_id, event_name,event_url, event_email from flyhh_events f, im_projects p where event_id = :event_id and p.project_id = f.project_id"

set list_id "stats_list"
set multirow "stats"

template::list::create \
    -name $list_id \
    -multirow $multirow \
    -elements {
        material_name {
            label "Accommodation"
        }
        capacity {
            label "Capacity"
            html {style "text-align:center;"}
            display_template {
                <if @stats.capacity@ nil><font color="red">inf</font></if>
                <else>@stats.capacity@</else>
            }
        }

        num_waitlist {
            label "Waitlist"
            html {style "text-align:center;"}
        }

        num_confirmed {
            label "Confirmed"
            html {style "text-align:center;"}
        }

        num_registered {
            label "Registered"
            html {style "text-align:center;"}
        }

        free_capacity {
            label "Free Capacity"
            html {style "text-align:center;"}
        }

        free_confirmed_capacity {
            label "Free Confirmed Capacity"
            html {style "text-align:center;"}
        }
    }


set sql "
    select *, (select count(*) from flyhh_event_participants ep where accommodation = em.material_id and ep.project_id = :project_id and event_participant_status_id = 82500) as num_waitlist 
    from flyhh_event_materials em 
    inner join im_materials m 
    on (em.material_id = m.material_id)
    inner join im_material_types mt
    on (mt.material_type_id = m.material_type_id)
    inner join flyhh_events e
    on (e.event_id = em.event_id)
    and em.capacity >0
    and e.project_id = :project_id
    and mt.material_type_id = 9002
    order by material_type,material_name
"
db_multirow stats $multirow $sql {
    if {$free_capacity eq ""} {set free_capacity $capacity}
    if {$free_confirmed_capacity eq ""} {set free_confirmed_capacity $capacity}
    if {$capacity eq "999"} {
        set free_capacity "Endless"
        set free_confirmed_capacity "Endless"
        set capacity "Endless"
    }
}

# ---------------------------------------------------------------
# Table with Lead / Follow information
# ---------------------------------------------------------------

set table_header_list [list "Course" "Role" "Capacity" "Waitlist" "Confirmed" "Registered"]
set table_header_html "<tr class='list-header'><th class='list-table'>[join $table_header_list "</th><th class='list-table'>"]</th></tr>"

set ctr 0
set bgcolor(0) " class=roweven "
set bgcolor(1) " class=rowodd "

set table_body_html ""
# First the materials where lead/follow matters
db_foreach materials "select em.material_id,m.material_name,material_nr,capacity,num_confirmed,num_registered,(select count(*) from flyhh_event_participants ep where course = em.material_id and ep.project_id = :project_id and event_participant_status_id = 82500) as num_waitlist from flyhh_event_materials em, im_materials m where event_id = :event_id and em.material_id = m.material_id and m.material_type_id=9004 and em.capacity != 0" {
    incr ctr
    if {![string match "*solo*" $material_nr]} {
        # This is a material with Lead & Follow
        set capacity [expr $capacity / 2]
        set num_lead_waitlist 0
        set num_lead_confirmed 0
        set num_lead_registered 0
        set num_follow_waitlist 0
        set num_follow_confirmed 0
        set num_follow_registered 0
        # Calculate the lead numbers
        db_foreach lead_$material_nr {
            select count(*) as num_lead, event_participant_status_id, lead_p from flyhh_event_participants where course = :material_id group by lead_p, event_participant_status_id
        } {
            if {$lead_p} {set role "lead"} else {set role "follow"}
            switch $event_participant_status_id {
                82500 {
                    incr num_${role}_waitlist $num_lead
                }
                82501 - 82502 - 82503 {
                    incr num_${role}_confirmed $num_lead
                }
                82504 {
                    incr num_${role}_registered $num_lead
                }
            }
        }
        append table_body_html "<tr$bgcolor([expr $ctr % 2])>\n<td class='list-table'>$material_name</td><td class='list-table'>Lead</td><td class='list-table'>$capacity</td><td class='list-table'>$num_lead_waitlist</td><td class='list-table'>$num_lead_confirmed</td><td class='list-table'>$num_lead_registered</td></tr>"
        append table_body_html "<tr$bgcolor([expr $ctr % 2])>\n<td class='list-table'>$material_name</td><td class='list-table'>Follow</td><td class='list-table'>$capacity</td><td class='list-table'>$num_follow_waitlist</td><td class='list-table'>$num_follow_confirmed</td><td class='list-table'>$num_follow_registered</td></tr>"
        
    } else {
        append table_body_html "<tr$bgcolor([expr $ctr % 2])>\n<td class='list-table'>$material_name</td><td class='list-table'>n/a</td><td class='list-table'>$capacity</td><td class='list-table'>$num_waitlist</td><td class='list-table'>$num_confirmed</td><td class='list-table'>$num_registered</td></tr>"
    }
}