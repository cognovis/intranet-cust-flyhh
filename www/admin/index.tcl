
set page_title "Flyhh Event Management - Administration Page"
set context [ad_context_bar $page_title]

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
        }
        actions {
            label "Actions"
            display_template {
                <a href="participants-list?project_id=@events.project_id@">see participants</a>
            }
        }
    }


set sql "select * from flyhh_events evt inner join im_projects prj on (prj.project_id = evt.project_id)"
db_multirow events $multirow $sql


