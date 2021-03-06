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

        num_checked_in {
            label "Checked In"
            html {style "text-align:center;"}
        }
    }


set sql "
    select capacity as planned_capacity, free_capacity,free_confirmed_capacity,material_name, em.material_id,
(select count(*) from flyhh_event_participants ep where accommodation = em.material_id and ep.project_id = :project_id and event_participant_status_id = 82500) as num_waitlist,
(select count(*) from flyhh_event_participants ep where accommodation = em.material_id and ep.project_id = :project_id and event_participant_status_id = 82502) as num_pending_payment,
(select count(*) from flyhh_event_participants ep where accommodation = em.material_id and ep.project_id = :project_id and event_participant_status_id = 82503) as num_partially_paid,
(select count(*) from flyhh_event_participants ep where accommodation = em.material_id and ep.project_id = :project_id and event_participant_status_id = 82504) as num_registered,
(select count(*) from flyhh_event_participants ep where accommodation = em.material_id and ep.project_id = :project_id and event_participant_status_id = 82507) as num_checked_in,
(select count(*) from flyhh_event_participants ep where accommodation = em.material_id and ep.project_id = :project_id and event_participant_status_id not in (82500,82505,82506)) as num_registered_occupants,
    (select sum(er.sleeping_spots) from flyhh_event_rooms er where er.room_material_id = em.material_id) as capacity,
    (select coalesce(1,0) from im_materials where parent_material_id = em.material_id) as has_children_p,
    (select count(*) from flyhh_event_room_occupants ro, flyhh_event_rooms er where er.room_material_id = em.material_id and ro.room_id = er.room_id and ro.project_id =:project_id and ro.person_id not in (select person_id from flyhh_event_participants where project_id = :project_id and event_participant_status_id in (82505,82506))) as occupants,
    (select count(*) from flyhh_event_room_occupants ro, flyhh_event_rooms er where er.room_material_id = em.material_id and ro.room_id = er.room_id and ro.project_id =:project_id and ro.person_id not in (select person_id from flyhh_event_participants where project_id = :project_id)) as other_occupants
    from flyhh_event_materials em 
    inner join im_materials m 
    on (em.material_id = m.material_id)
    inner join im_material_types mt
    on (mt.material_type_id = m.material_type_id)
    inner join flyhh_events e
    on (e.event_id = em.event_id)
    and em.capacity is not null
    and e.project_id = :project_id
    and mt.material_type_id = 9002
    order by material_type,material_name
"

db_multirow stats $multirow $sql {
    # Check if we have a category which has children
    if {$has_children_p eq 1} {
	
	set material_ids [db_list materials "select material_id from im_materials where parent_material_id = :material_id"]
	set child_occupants [db_string childs "select count(*) from flyhh_event_room_occupants ro, flyhh_event_rooms er, flyhh_event_participants p where p.accommodation in ([template::util::tcl_to_sql_list $material_ids]) and p.person_id = ro.person_id and ro.room_id = er.room_id and ro.project_id =:project_id" -default 0]
	set other_occupants [expr $other_occupants + $child_occupants]
    }
	
    if {$free_capacity eq ""} {set free_capacity $capacity}
    if {$free_confirmed_capacity eq ""} {set free_confirmed_capacity $capacity}
    if {$num_registered_occupants ne $occupants} {set occupants "<font color=red>$occupants</font>"}
#    set other_occupants [expr $capacity - $confirmed_occupants]
#    if {$confirmed_occupants ne ""} {set num_confirmed $confirmed_occupants}
}

# ---------------------------------------------------------------
# Table with Lead / Follow information
# ---------------------------------------------------------------

set table_header_list [list "Course" "Role" "Capacity" "Waitlist" "Pending Payment" "Partially Paid" "Registered" "Checked-In"]
set table_header_html "<tr class='list-header'><th class='list-table'>[join $table_header_list "</th><th class='list-table'>"]</th></tr>"

set ctr 0
set bgcolor(0) " class=roweven "
set bgcolor(1) " class=rowodd "

set table_body_html ""
# First the materials where lead/follow matters
db_foreach materials "select em.material_id,m.material_name,material_nr,capacity,material_type_id from flyhh_event_materials em, im_materials m where event_id = :event_id and em.material_id = m.material_id and m.material_type_id=9004 and em.capacity != 0 
order by material_type_id, material_name" {
    incr ctr
    if {![string match "*solo*" $material_nr]} {
        # This is a material with Lead & Follow
        set capacity [expr $capacity / 2]
        set num_lead_waitlist 0
        set num_lead_pending_payment 0
        set num_lead_partially_paid 0
        set num_lead_registered 0
	set num_lead_checked_in 0
        set num_follow_waitlist 0
        set num_follow_pending_payment 0
        set num_follow_partially_paid 0
        set num_follow_registered 0
	set num_follow_checked_in 0

	set num_lead_cancelled 0
        set num_follow_cancelled 0

        # Calculate the lead numbers
        db_foreach lead_$material_nr {
            select count(*) as num_role, event_participant_status_id, lead_p from flyhh_event_participants where course = :material_id and project_id = :project_id group by lead_p, event_participant_status_id
        } {
            if {$lead_p} {set role "lead"} else {set role "follow"}
            switch $event_participant_status_id {
                82500 {
                    incr num_${role}_waitlist $num_role
                }
                82502 {
                    incr num_${role}_pending_payment $num_role
                }
                82503 {
                    incr num_${role}_partially_paid $num_role
                }
                82504 {
                    incr num_${role}_registered $num_role
                }
                82507 {
                    incr num_${role}_checked_in $num_role
                }
		85505 - 82506 {
		    incr num_${role}_cancelled $num_role
		}
            }
        }
        set capacity_lead "[expr $num_lead_pending_payment + $num_lead_partially_paid + $num_lead_registered + $num_lead_checked_in] / $capacity / $num_lead_cancelled"
        set capacity_follow "[expr $num_follow_pending_payment + $num_follow_partially_paid + $num_follow_registered + $num_follow_checked_in] / $capacity / $num_follow_cancelled"
        append table_body_html "<tr$bgcolor([expr $ctr % 2])>\n<td class='list-table'>$material_name</td><td class='list-table'>Lead</td><td class='list-table'>$capacity_lead</td><td class='list-table'>$num_lead_waitlist</td><td class='list-table'>$num_lead_pending_payment</td><td class='list-table'>$num_lead_partially_paid</td><td class='list-table'>$num_lead_registered</td><td class='list-table'>$num_lead_checked_in</td></tr>"
        append table_body_html "<tr$bgcolor([expr $ctr % 2])>\n<td class='list-table'>$material_name</td><td class='list-table'>Follow</td><td class='list-table'>$capacity_follow</td><td class='list-table'>$num_follow_waitlist</td><td class='list-table'>$num_follow_pending_payment</td><td class='list-table'>$num_follow_partially_paid</td><td class='list-table'>$num_follow_registered</td><td class='list-table'>$num_follow_checked_in</td></tr>"

    } else {
	db_1row stats "select
(select count(*) from flyhh_event_participants ep where course = em.material_id and ep.project_id = :project_id and event_participant_status_id = 82500) as num_waitlist,
(select count(*) from flyhh_event_participants ep where course = em.material_id and ep.project_id = :project_id and event_participant_status_id = 82502) as num_pending_payment,
(select count(*) from flyhh_event_participants ep where course = em.material_id and ep.project_id = :project_id and event_participant_status_id = 82503) as num_partially_paid,
(select count(*) from flyhh_event_participants ep where course = em.material_id and ep.project_id = :project_id and event_participant_status_id = 82504) as num_registered,
(select count(*) from flyhh_event_participants ep where course = em.material_id and ep.project_id = :project_id and event_participant_status_id = 82507) as num_checked_in,
(select count(*) from flyhh_event_participants ep where course = em.material_id and ep.project_id = :project_id and event_participant_status_id in (82505,82506)) as num_cancelled
from flyhh_event_materials em where event_id = :event_id and em.material_id = :material_id"

        set capacity "[expr $num_pending_payment + $num_partially_paid + $num_registered] / $capacity / $num_cancelled"
        append table_body_html "<tr$bgcolor([expr $ctr % 2])>\n<td class='list-table'>$material_name</td><td class='list-table'>n/a</td><td class='list-table'>$capacity</td><td class='list-table'>$num_waitlist</td><td class='list-table'>$num_pending_payment</td><td class='list-table'>$num_partially_paid</td><td class='list-table'>$num_registered</td><td class='list-table'>$num_checked_in</td></tr>"

    }
}


# Append no material

db_foreach no_course "select em.material_id,m.material_name,material_nr,capacity,material_type_id from flyhh_event_materials em, im_materials m where event_id = :event_id and em.material_id = m.material_id and m.material_id = 55536" {
	db_1row stats "select
(select count(*) from flyhh_event_participants ep where course = em.material_id and ep.project_id = :project_id and event_participant_status_id = 82500) as num_waitlist,
(select count(*) from flyhh_event_participants ep where course = em.material_id and ep.project_id = :project_id and event_participant_status_id = 82502) as num_pending_payment,
(select count(*) from flyhh_event_participants ep where course = em.material_id and ep.project_id = :project_id and event_participant_status_id = 82503) as num_partially_paid,
(select count(*) from flyhh_event_participants ep where course = em.material_id and ep.project_id = :project_id and event_participant_status_id = 82504) as num_registered,
(select count(*) from flyhh_event_participants ep where course = em.material_id and ep.project_id = :project_id and event_participant_status_id = 82507) as num_checked_in,
(select count(*) from flyhh_event_participants ep where course = em.material_id and ep.project_id = :project_id and event_participant_status_id in (82505,82506)) as num_cancelled
from flyhh_event_materials em where event_id = :event_id and em.material_id = :material_id"

        set capacity "na"
        append table_body_html "<tr$bgcolor([expr $ctr % 2])>\n<td class='list-table'>$material_name</td><td class='list-table'>n/a</td><td class='list-table'>$capacity</td><td class='list-table'>$num_waitlist</td><td class='list-table'>$num_pending_payment</td><td class='list-table'>$num_partially_paid</td><td class='list-table'>$num_registered</td><td class='list-table'>$num_checked_in</td></tr>"
    
}

db_foreach materials "select em.material_id,m.material_name,material_nr,capacity,material_type_id from flyhh_event_materials em, im_materials m where event_id = :event_id and em.material_id = m.material_id and m.material_type_id=9008 and em.capacity != 0 order by material_type_id, material_name" {
    incr ctr
	db_1row stats "select
(select count(*) from flyhh_event_participants ep where bus_option = em.material_id and ep.project_id = :project_id and event_participant_status_id = 82500) as num_waitlist,
(select count(*) from flyhh_event_participants ep where bus_option = em.material_id and ep.project_id = :project_id and event_participant_status_id = 82502) as num_pending_payment,
(select count(*) from flyhh_event_participants ep where bus_option = em.material_id and ep.project_id = :project_id and event_participant_status_id = 82503) as num_partially_paid,
(select count(*) from flyhh_event_participants ep where bus_option = em.material_id and ep.project_id = :project_id and event_participant_status_id = 82504) as num_registered,
(select count(*) from flyhh_event_participants ep where bus_option = em.material_id and ep.project_id = :project_id and event_participant_status_id = 82507) as num_checked_in
from flyhh_event_materials em where event_id = :event_id and em.material_id = :material_id"

        set capacity "[expr $num_pending_payment + $num_partially_paid + $num_registered] / $capacity"
        append bus_body_html "<tr$bgcolor([expr $ctr % 2])>\n<td class='list-table'>$material_name</td><td class='list-table'>n/a</td><td class='list-table'>$capacity</td><td class='list-table'>$num_waitlist</td><td class='list-table'>$num_pending_payment</td><td class='list-table'>$num_partially_paid</td><td class='list-table'>$num_registered</td><td class='list-table'>$num_checked_in</td></tr>"
    }

set ctr 0
	db_foreach discount_stats "select material_name,
(select count(*) from flyhh_event_participants ep, im_invoice_items ii where ep.invoice_id = ii.invoice_id and ep.project_id = :project_id and ep.event_participant_status_id = 82502 and ii.item_material_id = em.material_id) as num_pending_payment,
(select count(*) from flyhh_event_participants ep, im_invoice_items ii where ep.invoice_id = ii.invoice_id and ep.project_id = :project_id and ep.event_participant_status_id = 82503 and ii.item_material_id = em.material_id) as num_partially_paid,
(select count(*) from flyhh_event_participants ep, im_invoice_items ii where ep.invoice_id = ii.invoice_id and ep.project_id = :project_id and ep.event_participant_status_id = 82504 and ii.item_material_id = em.material_id) as num_registered,
(select count(*) from flyhh_event_participants ep, im_invoice_items ii where ep.invoice_id = ii.invoice_id and ep.project_id = :project_id and ep.event_participant_status_id = 82507 and ii.item_material_id = em.material_id) as num_checked_in
from im_materials em where material_type_id = 9006" {
incr ctr
        set capacity "[expr $num_pending_payment + $num_partially_paid + $num_registered]"
        append bus_body_html "<tr$bgcolor([expr $ctr % 2])>\n<td class='list-table'>$material_name</td><td class='list-table'>n/a</td><td class='list-table'></td><td class='list-table'></td><td class='list-table'>$num_pending_payment</td><td class='list-table'>$num_partially_paid</td><td class='list-table'>$num_registered</td><td class='list-table'>$num_checked_in</td></tr>"
    }

# ---------------------------------------------------------------
# Sanity checks for classes and food
# ---------------------------------------------------------------

set we_accommodation_nr [db_string count "select count(*) from flyhh_event_participants ep, im_materials m where accommodation = m.material_id and ep.project_id = :project_id and event_participant_status_id in (82503,82504,82507) and m.material_uom_id = 323"]
set we_course_nr [db_string count "select count(*) from flyhh_event_participants ep, im_materials m where course = m.material_id and ep.project_id = :project_id and event_participant_status_id in (82503,82504,82507) and m.material_uom_id = 323"]
set accommodation_nr [db_string count "select count(*) from flyhh_event_participants ep, im_materials m where accommodation = m.material_id and ep.project_id = :project_id and event_participant_status_id in (82503,82504,82507) and m.material_uom_id = 328"]
set course_nr [db_string count "select count(*) from flyhh_event_participants ep, im_materials m where course = m.material_id and ep.project_id = :project_id and event_participant_status_id in (82503,82504,82507) and m.material_uom_id = 328"]

ds_comment "course_nr: $course_nr"
set table_checks_html "<tr class='list-header'><th class='list-table'>Type</th><th class='list-table'>Week</th><th class='list-table'>Weekend</th></tr>"
append table_checks_html "<tr$bgcolor(0)>\n<td class='list-table'>Accommodation</td><td class='list-table'>$accommodation_nr</td><td class='list-table'>$we_accommodation_nr</td></tr>"
append table_checks_html "<tr$bgcolor(1)>\n<td class='list-table'>Classes</td><td class='list-table'>$course_nr</td><td class='list-table'>$we_course_nr</td></tr>"

