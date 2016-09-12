ad_page_contract {

    event_stats.tcl
    @date 2015-03-09
}


set multirow "participants"
template::multirow create $multirow course level no_leads no_follows total

# Change this for the final tally to only checked in...
set participant_status_ids [list 82503 82504 82507]

db_1row event_info "select project_cost_center_id, p.project_id, event_name,event_url, event_email from flyhh_events f, im_projects p where event_id = :event_id and p.project_id = f.project_id"

# ---------------------------------------------------------------
# Loop through the courses and there for each level
# ---------------------------------------------------------------

set active_courses_list [db_list active_courses "select em.material_id from flyhh_event_materials em, im_materials m where em.material_id = m.material_id and m.material_type_id = 9004 and em.capacity >0 and em.event_id = :event_id"]

set available_levels_list [db_list available_levels "select distinct(level) from flyhh_event_participants where project_id = :project_id"]

foreach course $active_courses_list {

    foreach level $available_levels_list {
	# ---------------------------------------------------------------
	# Get the numbers for the participants
	# ---------------------------------------------------------------
	
	set no_leads [db_string no_leads "select count(participant_id) from flyhh_event_participants ep where project_id = :project_id and course = :course and level = :level and event_participant_status_id in ([template::util::tcl_to_sql_list $participant_status_ids]) and lead_p = 't'"]
	set no_follows [db_string no_leads "select count(participant_id) from flyhh_event_participants ep where project_id = :project_id and course = :course and level = :level and event_participant_status_id in ([template::util::tcl_to_sql_list $participant_status_ids]) and lead_p = 'f'"]
	set total [expr $no_leads + $no_follows]
	if {$total >0 } {
	    template::multirow append $multirow [im_material_name -material_id $course] [im_category_from_id $level] $no_leads $no_follows $total
	}
    }
}


template::list::create \
    -name level_list \
    -multirow $multirow \
    -elements {
        course {
            label "Course"
        }
        level {
            label "Level"
            html {style "text-align:center;"}
        }
        no_leads {
            label "Leads"
            html {style "text-align:center;"}
        }
        no_follows {
            label "Follows"
            html {style "text-align:center;"}
        }
        total {
            label "Total"
            html {style "text-align:center;"}
        }
    }
