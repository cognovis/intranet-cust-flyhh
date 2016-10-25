ad_page_contract {

    event_stats.tcl
    @date 2015-03-09
}


# Get the accommodation types
set barn_type_id 49731
set barn_we_type_id 53387
set acc_type_ids [db_list acc_types "select material_id from im_materials where material_type_id = 9002 and material_uom_id = 328 and material_id not in (49731,53387)"]
set acc_we_type_ids [db_list acc_types "select material_id from im_materials where material_type_id = 9002 and material_uom_id = 323 and material_id not in (49731,53387)"]

# Change this for the final tally to only checked in...
set participant_status_ids [list 82504 82507]

set project_ids [db_list project_ids "select fe.project_id from flyhh_events fe, im_projects p where fe.project_id = p.project_id and p.project_status_id = 76 order by p.start_date asc"]

set multirow "occupants"
template::multirow create $multirow event_name week_participants weekend_participants other_occupants food_meat food_vegi food_we_meat food_we_vegi normal_nights food

template::multirow create finance event_name accommodation_cost food_cost accommodation_income food_income course_income

set total_accommodation_cost 0
set total_food_cost 0

foreach project_id $project_ids {

    set event_name [db_string name "select event_name from flyhh_events where project_id = :project_id"]

    # ---------------------------------------------------------------
    # Get the numbers for the participants
    # ---------------------------------------------------------------

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
    # Calculate Food
    # ---------------------------------------------------------------
    set food_meat [db_string wp "select count(participant_id) from flyhh_event_participants ep where ep.project_id = :project_id and ep.food_choice=33314 and ep.event_participant_status_id in ([template::util::tcl_to_sql_list $participant_status_ids])"]
    set food_vegi [db_string wp "select count(participant_id) from flyhh_event_participants ep where ep.project_id = :project_id and ep.food_choice=33313 and ep.event_participant_status_id in ([template::util::tcl_to_sql_list $participant_status_ids])"]
    set food_we_meat [db_string wp "select count(participant_id) from flyhh_event_participants ep where ep.project_id = :project_id and ep.food_choice=52340 and ep.event_participant_status_id in ([template::util::tcl_to_sql_list $participant_status_ids])"]
    set food_we_vegi [db_string wp "select count(participant_id) from flyhh_event_participants ep where ep.project_id = :project_id and ep.food_choice=52341 and ep.event_participant_status_id in ([template::util::tcl_to_sql_list $participant_status_ids])"]
    if {$food_meat ne 0 || $food_vegi ne 0} {
	set food_others_meat [expr $other_occupants * $food_meat / ($food_meat + $food_vegi)]
    }
    set food_others_vegi [expr $other_occupants - $food_others_meat]
    set food_meat [expr $food_meat + $food_others_meat]
    set food_vegi [expr $food_vegi + $food_others_vegi]
    set food_we_meat [expr $food_meat + $food_we_meat]
    set food_we_vegi [expr $food_vegi + $food_we_vegi]

    # ---------------------------------------------------------------
    # Calculate the totals
    # ---------------------------------------------------------------
    if {$project_id eq 52316} {
	# BCC
	set normal_nights [expr $acc_participants * 7 + $we_acc_participants *3 + $other_occupants *7]
	set normal_nights [expr ($barn_participants * 7 + $we_barn_participants *3)/2 + $normal_nights]
	set food [expr ($food_we_meat + $food_we_vegi) * 3 + ($food_meat + $food_vegi) *4]
    } else {
	# SCC
	set normal_nights [expr $acc_participants * 6 + $we_acc_participants *2 + $other_occupants *6]
	set normal_nights [expr ($barn_participants * 6 + $we_barn_participants *2)/2 + $normal_nights]
	set food [expr ($food_we_meat + $food_we_vegi) * 3 + ($food_meat + $food_vegi) *3]
    }

    # ---------------------------------------------------------------
    # Append the numbers to the multirow
    # ---------------------------------------------------------------
    
    set acc_participants [expr $acc_participants + $barn_participants +$other_occupants]
    set we_acc_participants [expr $we_acc_participants + $we_barn_participants  + $acc_participants]
    template::multirow append $multirow $event_name $acc_participants $we_acc_participants $other_occupants $food_meat $food_vegi $food_we_meat $food_we_vegi $normal_nights $food

    # ---------------------------------------------------------------
    # Get the financial data
    # ---------------------------------------------------------------
    set accommodation_cost [expr $normal_nights  *18 *1.09]
    set food_cost [expr ($food * 25 *1.19 + ($food_meat + $food_vegi) *14*1.19)]

    # Find all invoice items for this camp where the invoice is paid or partially paid
    set accommodation_income ""
    set food_income ""
    set course_income ""

    # Add totals
    set total_accommodation_cost [expr $accommodation_cost + $total_accommodation_cost]
    set total_food_cost [expr $food_cost + $total_food_cost]

    template::multirow append finance $event_name $accommodation_cost $food_cost $accommodation_income $food_income $course_income    
}
template::multirow append finance "Total" $total_accommodation_cost $total_food_cost $accommodation_income $food_income $course_income    

template::list::create \
    -name occ_list \
    -multirow $multirow \
    -elements {
        event_name {
            label "Event Name"
        }
        week_participants {
            label "Full week"
            html {style "text-align:center;"}
        }
        weekend_participants {
            label "Weekend"
            html {style "text-align:center;"}
        }
	food_we_meat {
	    label "Food WE Meat"
            html {style "text-align:center;"}
        }	    
	food_we_vegi {
	    label "Food WE Vegi"
            html {style "text-align:center;"}
        }	    
	food_meat {
	    label "Food Meat"
            html {style "text-align:center;"}
        }	    
	food_vegi {
	    label "Food Vegi"
            html {style "text-align:center;"}
        }	    
    }

template::list::create \
    -name finance_list \
    -multirow finance \
    -elements {
        event_name {
            label "Event Name"
        }
	accommodation_cost {
	    label "Accommodation Cost"
            html {style "text-align:center;"}
        }	    
	food_cost {
	    label "Food Cost"
            html {style "text-align:center;"}
        }	    
    }

