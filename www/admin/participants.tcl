ad_page_contract {
    
    flying hamburger registration page
    
    @author Neophytos Demetriou (neophytos@azet.sk)
    @creation-date 2014-10-23
    @last-modified 2014-10-23
    @cvs-id $Id$
} {
    project_id:integer,notnull,optional
} -properties {
} -validate {
} -errors {
}



# For debugging purposes,
# we use an arbitrary project_id that we create for
# company 8720, i.e. Flying Hamburger Events UG.
#
set sql "select project_id from im_projects where project_type_id=102 and company_id=8720 limit 1"
set project_id [db_string some_project_id $sql]

set page_title "List of Participants"
set context [ad_context_bar "List of Participants"]

set list_id "event_participants_list"
set multirow "event_participants"


template::list::create \
    -name $list_id \
    -multirow $multirow \
    -elements {
        full_name {
            label "Name"
            link_url_eval {[export_vars -base ../registration { { participant_id $participant_id } }]}
        }
        email {
            label "Email"
        }
        lead_or_follow {
            label "Lead/Follow"
        }
        partner_email {
            label "Partner"
        }
        roommates {
            label "Roommates"
            display_template { something }
        }
    }


db_multirow event_participants $multirow {
    select *,
        cc.first_names || ' ' || cc.last_name as full_name,
        case when lead_p then 'Lead' else 'Follow' end as lead_or_follow
    from im_event_participants ep 
    inner join cc_users cc 
    on (ep.person_id=cc.user_id) 
    where project_id=:project_id
}

