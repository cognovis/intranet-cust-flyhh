
set page_title "Flyhh Event Management - Administration Page"
set context ""
set context_bar [ad_context_bar $page_title]

set list_id "events_list"
set multirow "events"

template::list::create \
    -name $list_id \
    -multirow $multirow \
    -elements {
        event_id {
            label "Event ID"
        }
        event_name {
            label "Event Name"
            link_url_eval {[export_vars -base event-one {event_id}]}
        }
        cost_center {
            label "Cost Center"
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
                <a class="button" href="participants-list?project_id=@events.project_id@">see participants</a>
                <a class="button" href="../registration?project_id=@events.project_id@">add participant</a>
            }
        }
    }


set sql "select *, im_cost_center_code_from_id(project_cost_center_id) as cost_center from flyhh_events evt inner join im_projects prj on (prj.project_id = evt.project_id)"
db_multirow events $multirow $sql


