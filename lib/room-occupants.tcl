if {![info exists room_id] && ![info exists project_id]} {
    ad_page_contract {
        @author malte.sussdorff@cognovis.de
    } {
	   room_id:integer
	   project_id:integer
    }
}

if {![info exists return_url] || "" == $return_url} { set return_url [im_url_with_query] }
set user_id [ad_maybe_redirect_for_registration]


# ----------------------------------------------------
# Create a "multirow" to show the results

multirow create occupants occupant_name partner_name occupant_url partner_url 

template::list::create \
-name occupants_list \
-multirow occupants \
-elements {
    occupant {
        label {[::flyhh::mc Occupant "Occupant"]}
        display_template {
            <a href='@occupants.occupant_url;noquote@'>@occupants.occupant_name;noquote@</a>
        }
    }
    partner {
        label {[::flyhh::mc Partner "Partner"]}
        html {style "text-align:center;"}
        display_template {
            <a href='@occupants.partner_url;noquote@'>@occupants.partner_name;noquote@</a>
        }
    }
}

set occupants_sql "
	select person_id, participant_id, partner_participant_id, partner_person_id
	from	   flyhh_event_participants
	where  room_id = :room_id and project_id = :project_id
    "
    
db_multirow -extend {occupant_name partner_name occupant_url partner_url} occupants occupants_query $occupants_sql {
    set occupant_name [person::name -person_id $person_id]
    set occupant_url [export_vars -base "/flyhh/admin/registration" -url {participant_id project_id}]
    if {$partner_participant_id ne ""} {
        set partner_name [person::name -person_id $person_id]
        set partner_url [export_vars -base "/flyhh/admin/registration" -url {{participant_id $partner_participant_id} project_id}]
    } else {
        set partner_name ""
        set partner_url ""
    }
}
