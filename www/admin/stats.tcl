ad_page_contract {
    @author Neophytos Demetriou (neophytos@azet.sk)
    @creation-date 2014-11-13
    @last-modified 2014-11-13
} {
    project_id:integer,notnull
} -validate {

    check_event_exists -requires {project_id:integer} {

        ::flyhh::check_event_exists -project_id $project_id

    }

}

set sql "select * from flyhh_events where project_id=:project_id" 
db_1row event_info $sql

set page_title "Stats for $event_name"
set context_bar [ad_context_bar $page_title]

set list_id "stats_list"
set multirow "stats"

template::list::create \
    -name $list_id \
    -multirow $multirow \
    -elements {
        material_id {
            label "Material ID"
        }
        material_type {
            label "Material Type"
        }
        material_name {
            label "Material"
        }
        capacity {
            label "Capacity"
            html {style "text-align:center;"}
            display_template {
                <if @stats.capacity@ nil><font color="red">inf</font></if>
                <else>@stats.capacity@</else>
            }
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
    select * 
    from flyhh_event_materials em 
    inner join im_materials m 
    on (em.material_id = m.material_id)
    inner join im_material_types mt
    on (mt.material_type_id = m.material_type_id)
    order by material_type
"
db_multirow stats $multirow $sql

