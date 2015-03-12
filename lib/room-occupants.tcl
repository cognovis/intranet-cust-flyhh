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
    note {
        label {[::flyhh::mc Note "Note"]}
        display_template {
            @occupants.note;noquote@
        }        
    }
}

set occupants_sql "
	select ro.person_id, ep.participant_id, ep.partner_participant_id, ep.partner_person_id,ro.note
	from	   flyhh_event_room_occupants ro
	left outer join flyhh_event_participants ep on (ep.person_id = ro.person_id and ep.project_id = ro.project_id)
	where  ro.room_id = :room_id and ro.project_id = :project_id
	order by im_name_from_id(ro.person_id)
    "
    
db_multirow -extend {occupant_name partner_name occupant_url partner_url} occupants occupants_query $occupants_sql {
    set note  [template::util::richtext::get_property html_value $note]
    set occupant_name [person::name -person_id $person_id]
    if {$participant_id eq ""} {
        set company_id [db_string company_id "select company_id from im_companies where primary_contact_id =:person_id" -default ""]
        if {$company_id eq ""} {
            set occupant_url [export_vars -base "/intranet/user/view" -url {{user_id $person_id}}]            
        } {
            set occupant_url [export_vars -base "/intranet/companies/view" -url {company_id}]            
        }

    } else {
        set occupant_url [export_vars -base "/flyhh/admin/registration" -url {participant_id project_id}]
    }

    if {$partner_participant_id ne ""} {
        set partner_name [person::name -person_id $partner_person_id]
        set partner_url [export_vars -base "/flyhh/admin/registration" -url {{participant_id $partner_participant_id} project_id}]
    } else {
        set partner_name ""
        set partner_url ""
    }
}
