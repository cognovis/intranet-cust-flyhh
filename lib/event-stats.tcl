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
        occupants {
            label "Assigned"
            html {style "text-align:center;"}
        }
        other_occupants {
            label "Others"
            html {style "text-align:center;"}
        }

        num_confirmed {
            label "Confirmed"
            html {style "text-align:center;"}
        }

        num_pending_payment {
            label "Pending Payment"
            html {style "text-align:center;"}
        }

        num_partially_paid {
            label "Partially Paid"
            html {style "text-align:center;"}
        }

        num_registered {
            label "Registered"
            html {style "text-align:center;"}
        }

    }


set sql "
    select capacity as planned_capacity, free_capacity,free_confirmed_capacity,material_name,
(select count(*) from flyhh_event_participants ep where accommodation = em.material_id and ep.project_id = :project_id and event_participant_status_id = 82501) as num_confirmed,
(select count(*) from flyhh_event_participants ep where accommodation = em.material_id and ep.project_id = :project_id and event_participant_status_id = 82502) as num_pending_payment,
(select count(*) from flyhh_event_participants ep where accommodation = em.material_id and ep.project_id = :project_id and event_participant_status_id = 82503) as num_partially_paid,
(select count(*) from flyhh_event_participants ep where accommodation = em.material_id and ep.project_id = :project_id and event_participant_status_id = 82504) as num_registered,
    (select sum(er.sleeping_spots) from flyhh_event_rooms er where er.room_material_id = em.material_id) as capacity,
    (select count(*) from flyhh_event_room_occupants ro, flyhh_event_rooms er where er.room_material_id = em.material_id and ro.room_id = er.room_id and ro.project_id =:project_id) as occupants,
    (select count(*) from flyhh_event_room_occupants ro, flyhh_event_rooms er where er.room_material_id = em.material_id and ro.room_id = er.room_id and ro.project_id =:project_id and ro.person_id not in (select person_id from flyhh_event_participants where project_id = :project_id)) as other_occupants,
    (select count(*) from flyhh_event_room_occupants ro, flyhh_event_rooms er, flyhh_event_participants ep where er.room_material_id = em.material_id and ro.room_id = er.room_id and ep.person_id = ro.person_id and ep.project_id = ro.project_id and ro.project_id =:project_id and ep.event_participant_status_id in (82501,82502,82503,82504)) as confirmed_occupants 
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
#    set other_occupants [expr $capacity - $confirmed_occupants]
#    if {$confirmed_occupants ne ""} {set num_confirmed $confirmed_occupants}
}

# ---------------------------------------------------------------
# Table with Lead / Follow information
# ---------------------------------------------------------------

set table_header_list [list "Course" "Role" "Capacity" "Waitlist" "Confirmed" "Pending Payment" "Partially Paid" "Registered"]
set table_header_html "<tr class='list-header'><th class='list-table'>[join $table_header_list "</th><th class='list-table'>"]</th></tr>"

set ctr 0
set bgcolor(0) " class=roweven "
set bgcolor(1) " class=rowodd "

set table_body_html ""
# First the materials where lead/follow matters
db_foreach materials "select em.material_id,m.material_name,material_nr,capacity,material_type_id from flyhh_event_materials em, im_materials m where event_id = :event_id and em.material_id = m.material_id and m.material_type_id=9004 and em.capacity != 0" {
    incr ctr
    if {![string match "*solo*" $material_nr]} {
        # This is a material with Lead & Follow
        set capacity [expr $capacity / 2]
        set num_lead_waitlist 0
        set num_lead_confirmed 0
        set num_lead_pending_payment 0
        set num_lead_partially_paid 0
        set num_lead_registered 0
        set num_follow_waitlist 0
        set num_follow_confirmed 0
        set num_follow_pending_payment 0
        set num_follow_partially_paid 0
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
                82501 {
                    incr num_${role}_confirmed $num_lead
                }
                82502 {
                    incr num_${role}_pending_payment $num_lead
                }
                82503 {
                    incr num_${role}_partially_paid $num_lead
                }
                82504 {
                    incr num_${role}_registered $num_lead
                }
            }
        }
        set capacity_lead "[expr $num_lead_confirmed + $num_lead_pending_payment + $num_lead_partially_paid + $num_lead_registered] / $capacity"
        set capacity_follow "[expr $num_follow_confirmed + $num_follow_pending_payment + $num_follow_partially_paid + $num_follow_registered] / $capacity"
        append table_body_html "<tr$bgcolor([expr $ctr % 2])>\n<td class='list-table'>$material_name</td><td class='list-table'>Lead</td><td class='list-table'>$capacity_lead</td><td class='list-table'>$num_lead_waitlist</td><td class='list-table'>$num_lead_confirmed</td><td class='list-table'>$num_lead_pending_payment</td><td class='list-table'>$num_lead_partially_paid</td><td class='list-table'>$num_lead_registered</td></tr>"
        append table_body_html "<tr$bgcolor([expr $ctr % 2])>\n<td class='list-table'>$material_name</td><td class='list-table'>Follow</td><td class='list-table'>$capacity_follow</td><td class='list-table'>$num_follow_waitlist</td><td class='list-table'>$num_follow_confirmed</td><td class='list-table'>$num_follow_pending_payment</td><td class='list-table'>$num_follow_partially_paid</td><td class='list-table'>$num_follow_registered</td></tr>"
        
    } else {
	db_1row stats "select
(select count(*) from flyhh_event_participants ep where course = em.material_id and ep.project_id = :project_id and event_participant_status_id = 82500) as num_waitlist,
(select count(*) from flyhh_event_participants ep where course = em.material_id and ep.project_id = :project_id and event_participant_status_id = 82501) as num_confirmed,
(select count(*) from flyhh_event_participants ep where course = em.material_id and ep.project_id = :project_id and event_participant_status_id = 82502) as num_pending_payment,
(select count(*) from flyhh_event_participants ep where course = em.material_id and ep.project_id = :project_id and event_participant_status_id = 82503) as num_partially_paid,
(select count(*) from flyhh_event_participants ep where course = em.material_id and ep.project_id = :project_id and event_participant_status_id = 82504) as num_registered 
from flyhh_event_materials em where event_id = :event_id and em.material_id = :material_id"

        set capacity "[expr $num_confirmed + $num_pending_payment + $num_partially_paid + $num_registered] / $capacity"
        append table_body_html "<tr$bgcolor([expr $ctr % 2])>\n<td class='list-table'>$material_name</td><td class='list-table'>n/a</td><td class='list-table'>$capacity</td><td class='list-table'>$num_waitlist</td><td class='list-table'>$num_confirmed</td><td class='list-table'>$num_pending_payment</td><td class='list-table'>$num_partially_paid</td><td class='list-table'>$num_registered</td></tr>"
    }

set bus_body_html ""
# First the materials where lead/follow matters
db_foreach materials "select em.material_id,m.material_name,material_nr,capacity,material_type_id from flyhh_event_materials em, im_materials m where event_id = :event_id and em.material_id = m.material_id and m.material_type_id=9008 and em.capacity != 0" {
    incr ctr
	db_1row stats "select
(select count(*) from flyhh_event_participants ep where bus_option = em.material_id and ep.project_id = :project_id and event_participant_status_id = 82500) as num_waitlist,
(select count(*) from flyhh_event_participants ep where bus_option = em.material_id and ep.project_id = :project_id and event_participant_status_id = 82501) as num_confirmed,
(select count(*) from flyhh_event_participants ep where bus_option = em.material_id and ep.project_id = :project_id and event_participant_status_id = 82502) as num_pending_payment,
(select count(*) from flyhh_event_participants ep where bus_option = em.material_id and ep.project_id = :project_id and event_participant_status_id = 82503) as num_partially_paid,
(select count(*) from flyhh_event_participants ep where bus_option = em.material_id and ep.project_id = :project_id and event_participant_status_id = 82504) as num_registered 
from flyhh_event_materials em where event_id = :event_id and em.material_id = :material_id"

        set capacity "[expr $num_confirmed + $num_pending_payment + $num_partially_paid + $num_registered] / $capacity"
        append bus_body_html "<tr$bgcolor([expr $ctr % 2])>\n<td class='list-table'>$material_name</td><td class='list-table'>n/a</td><td class='list-table'>$capacity</td><td class='list-table'>$num_waitlist</td><td class='list-table'>$num_confirmed</td><td class='list-table'>$num_pending_payment</td><td class='list-table'>$num_partially_paid</td><td class='list-table'>$num_registered</td></tr>"
    }
}
