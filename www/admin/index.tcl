
set company_id [parameter::get -parameter provider_company_id -default 8720]
set sql "select company_name from im_companies where company_id=:company_id"
set provider_company_name [db_string provider_company_name $sql -default ""]
set provider_company_link [export_vars -base /intranet/companies/view {company_id}]

set page_title "Flyhh Event Management - Administration Page"
set context ""
set context_bar [ad_context_bar $page_title]

set list_id "events_list"
set multirow "events"

template::list::create \
    -name $list_id \
    -multirow $multirow \
    -elements {
        project_id {
            label "Project ID"
            link_url_eval {[export_vars -base /intranet/projects/view {project_id}]}
        }
        event_name {
            label "Event Name"
            link_url_eval {[export_vars -base event-one {event_id}]}
        }
        cost_center {
            label "Cost Center"
        }
        registrations {
            label "Registrations"
	    display_template {
		@events.registrations;noquote@
	    }
        }
        pending_payment {
            label "Pending Payment"
	    display_template {
		<div align=center>@events.pending_payment;noquote@</div>
	    }
        }
        participants {
            label "Participants"
	    display_template {
		@events.participants;noquote@
	    }
        }
        enabled_p {
            label "Enabled?"
            display_template {
                <if @events.enabled_p@ true>
                    yes
                </if>
                <else>
                    no
                </else>
            }
        }
        actions {
            label "Actions"
            display_template {
                <a class="button" href="stats?project_id=@events.project_id@">stats</a>
                <a class="button" href="participants-list?project_id=@events.project_id@">see participants</a>
                <a class="button" href="registration?project_id=@events.project_id@">add participant</a>
            }
        }
    }


set sql "select *, im_cost_center_code_from_id(project_cost_center_id) as cost_center from flyhh_events evt inner join im_projects prj on (prj.project_id = evt.project_id) where prj.project_status_id = 76"

db_multirow -extend {pending_payment registrations participants} events $multirow $sql {
    set registrations [db_string registrations "select count(*) from flyhh_event_participants where project_id = :project_id and event_participant_status_id not in (82505,82506)"]

    set previous_projects [db_list previous_events "select e.project_id from flyhh_events e, im_projects p where project_cost_center_id = :project_cost_center_id and e.project_id = p.project_id and p.start_date < now() order by e.start_date"]
    set previous_registrations [list]
    set previous_participants [list]
    foreach previous_project_id $previous_projects {
	lappend previous_registrations [db_string registrations "select count(*) from flyhh_event_participants where project_id = :previous_project_id and event_participant_status_id not in (82505,82506)"]
	lappend previous_participants [db_string registrations "select count(*) from flyhh_event_participants where project_id = :previous_project_id and event_participant_status_id in (82503,82504,82507)"]
    }
 
   set pending_payment [db_string registrations "select count(*) from flyhh_event_participants where project_id = :project_id and event_participant_status_id = [flyhh::status::pending_payment]"]

    set participants [db_string registrations "select count(*) from flyhh_event_participants where project_id = :project_id and event_participant_status_id in (82503,82504,82507)"]

    if {$registrations < [lindex $previous_registrations 0]} {
	set registrations "<font color='red'>$registrations</font> ([join $previous_registrations " - "])"
    } else {
	set registrations "<font color='green'>$registrations</font> ([join $previous_registrations " - "])"
    }

    if {$participants < [lindex $previous_participants 0]} {
	set participants "<font color='red'>$participants</font> ([join $previous_participants " - "])"
    } else {
	set participants "<font color='green'>$participants</font> ([join $previous_participants " - "])"
    }

}


set list_id "finance_list"
set multirow "finance"

template::list::create \
    -name $list_id \
    -multirow $multirow \
    -elements {
        event_name {
            label "Event Name"
            link_url_eval {[export_vars -base event-one {event_id}]}
        }
        course {
            label "Course Income"
        }
        accommodation {
            label "Accommodation Income"
        }
        accommodation_cost {
            label "Accommodation Cost"
        }
        shuttle {
            label "Shuttle Income"
        }
        others {
            label "Others"
        }
    }




set sql "select * from flyhh_events evt inner join im_projects prj on (prj.project_id = evt.project_id) where prj.project_status_id = 76"

db_multirow -extend {course accommodation accommodation_cost shuttle others} finance $multirow $sql {
    
    set course 0
    set accommodation 0
    set shuttle 0
    set others 0
    set profit 0

    db_foreach items "select round(sum(item_units*price_per_unit)) as amount,material_type_id from im_invoice_items ii, im_materials m where project_id = :project_id and ii.item_material_id = m.material_id group by material_type_id" {
	switch $material_type_id {
	    9004 - 9006 {
		set course [expr $course + $amount]
	    }
	    9002 - 9007 {
		set accommodation [expr $accommodation + $amount]
	    }
	    9008 {
		set shuttle [expr $shuttle + $amount]
	    }
	    9000 - 9001 {
		set others [expr $others + $amount]
	    }
	}
    }

    # Get the accommodation types
    set barn_type_id 49731
    set barn_we_type_id 53387
    set acc_type_ids [db_list acc_types "select material_id from im_materials where material_type_id = 9002 and material_uom_id = 328 and material_id not in (49731,53387)"]
    set acc_we_type_ids [db_list acc_types "select material_id from im_materials where material_type_id = 9002 and material_uom_id = 323 and material_id not in (49731,53387)"]

    # Change this for the final tally to only checked in...
    set participant_status_ids [list 82503 82504 82507]

    set acc_participants [db_string ap "select count(participant_id) from flyhh_event_participants ep, flyhh_event_room_occupants ro where ep.accommodation in ([template::util::tcl_to_sql_list $acc_type_ids]) and ep.project_id = :project_id and ep.project_id = ro.project_id and ep.person_id = ro.person_id and ep.event_participant_status_id in ([template::util::tcl_to_sql_list $participant_status_ids])"]

    set we_acc_participants [db_string wp "select count(participant_id) from flyhh_event_participants ep, flyhh_event_room_occupants ro where ep.accommodation in ([template::util::tcl_to_sql_list $acc_we_type_ids]) and ep.project_id = :project_id and ep.project_id = ro.project_id and ep.person_id = ro.person_id and ep.event_participant_status_id in ([template::util::tcl_to_sql_list $participant_status_ids])"]

    set barn_participants [db_string bp "select count(participant_id) from flyhh_event_participants ep, flyhh_event_room_occupants ro where ep.accommodation = :barn_type_id and ep.project_id = :project_id and ep.project_id = ro.project_id and ep.person_id = ro.person_id and ep.event_participant_status_id in ([template::util::tcl_to_sql_list $participant_status_ids])"]

    set we_barn_participants [db_string bwp "select count(participant_id) from flyhh_event_participants ep, flyhh_event_room_occupants ro where ep.accommodation = :barn_we_type_id and ep.project_id = :project_id and ep.project_id = ro.project_id and ep.person_id = ro.person_id and ep.event_participant_status_id in ([template::util::tcl_to_sql_list $participant_status_ids])"]

    # ---------------------------------------------------------------
    # Get the number for the other occupants
    # ---------------------------------------------------------------
    
    # Other occupants always stay for the whole week. We ignore the ones booked into a WE room or we have stored in the barn
    set other_occupants [db_string oo "select count(person_id) from flyhh_event_room_occupants ro, flyhh_event_rooms er where ro.project_id = :project_id and ro.room_id = er.room_id and er.room_material_id in ([template::util::tcl_to_sql_list $acc_type_ids]) and ro.person_id not in (select person_id from flyhh_event_participants where project_id = :project_id)"]

    # ---------------------------------------------------------------
    # Calculate the totals
    # ---------------------------------------------------------------
    if {$project_id eq 52316} {
	# BCC
	set normal_nights [expr $acc_participants * 7 + $we_acc_participants *3 + $other_occupants *7]
	set barn_nights [expr $barn_participants * 7 + $we_barn_participants *3]
    } else {
	# SCC
	set normal_nights [expr $acc_participants * 6 + $we_acc_participants *2 + $other_occupants *6]
	set barn_nights [expr $barn_participants * 6 + $we_barn_participants *2]
    }

    set food [expr $normal_nights + $barn_nights]

    set accommodation_cost [expr {double(round([expr $normal_nights * 18 * 1.07 + $barn_nights * 9 * 1.07 + $food * 27 * 1.19] * 100))/100}]
		
}
