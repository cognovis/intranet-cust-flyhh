ad_page_contract {

    @author Neophytos Demetriou (neophytos@azet.sk)
    @creation-date 2014-11-02
    @last-modified 2014-11-04


} {
    project_id:integer,notnull
    participant_id:integer,multiple,notnull
    bulk_action:trim,notnull
    return_url:trim,notnull
} -validate {

    allowed_bulk_actions -requires {bulk_action} {
        if { -1 == [lsearch -exact [list "Set to Confirmed" "Set to Cancelled" "Set to Waitlist" "Send Mail" "Assign Room" "Set to Checked-In"] $bulk_action] } {
            ad_complain "page requires an allowed bulk action"
        }
    }    
}

switch -exact $bulk_action {
   "Set to Confirmed" { 
        rp_internal_redirect participant-confirm.tcl
    }
   "Set to Waitlist" { 
       db_transaction {

	   foreach id $participant_id {

	       # Check if the participant is currently cancelled. Otherwise ignore.
	       set cancelled_p [db_string cancelled "select 1 from flyhh_event_participants where participant_id = :participant_id and event_participant_status_id = [::flyhh::status::cancelled]" -default 0]
	       if {$cancelled_p} {
		   db_dml update_status "
            update flyhh_event_participants 
            set event_participant_status_id=[::flyhh::status::waiting_list]
            where participant_id=:participant_id 
        "
	       }
	   }
       }
       ad_returnredirect $return_url
    }
   "Set to Cancelled" { 

        db_transaction {
            foreach id $participant_id {
                ::flyhh::set_participant_status \
                    -participant_id $id \
                    -to_status "Cancelled"
        
                # ::flyhh::send_cancellation_mail $id        
            }
        }       
	ad_returnredirect $return_url
    }
    "Set to Checked-In" {
	db_transaction {

	    foreach id $participant_id {
		
		db_dml update_status "
                 update flyhh_event_participants 
                 set event_participant_status_id=[::flyhh::status::checked_in]
                 where participant_id=:participant_id 
                "
	    }
	    ad_returnredirect $return_url
	}
    }

    "Send Mail" {
        db_1row event_info "select project_cost_center_id, p.project_id, event_url, event_email, project_name from flyhh_events f, im_projects p where p.project_id = :project_id and p.project_id = f.project_id"
        set party_ids [db_list party_ids "select person_id from flyhh_event_participants where participant_id in ([template::util::tcl_to_sql_list $participant_id])"]
        set mail_url [export_vars -base "[apm_package_url_from_key "intranet-mail"]mail" -url {{object_id $project_id} {party_ids $party_ids} {subject "${project_name}: "} {from_addr $event_email} return_url}]

        ad_returnredirect $mail_url 
    }
    "Assign Room" {
        ad_returnredirect [export_vars -base "participant-room-assign" -url {{participant_ids $participant_id} project_id return_url}]
    }
}
