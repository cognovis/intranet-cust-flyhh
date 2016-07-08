
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
#set sql "select *, im_cost_center_code_from_id(project_cost_center_id) as cost_center from flyhh_events evt inner join im_projects prj on (prj.project_id = evt.project_id)"
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


