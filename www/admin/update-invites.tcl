ad_page_contract {
    Update Invite Participants to Events

    This was only needed once as we send out previous mailings without the invite log functionality.
} {
    
}

set past_project_ids [db_list events "select p.project_id from flyhh_events e, im_projects p where e.project_id = p.project_id and p.project_status_id != [im_project_status_open]"]

set emails [list]
foreach past_project_id $past_project_ids {
    db_foreach project_info "select email from parties p, flyhh_event_participants ep where ep.person_id = p.party_id and ep.project_id = :past_project_id" {
	lappend emails $email
    }
}

foreach email $emails {
    set party_id [party::get_by_email -email "$email"]
    foreach event_id [list 52315 51335] {
	set project_id $event_id
	incr project_id
	# Try to find the log_id
	if {$party_id ne ""} {
	    set mail_log_id [db_string mail_log "select ml.log_id from acs_mail_log ml, acs_mail_log_recipient_map rm
where rm.log_id = ml.log_id
and  rm.recipient_id = :party_id
and ml.context_id = :project_id limit 1" -default ""]
	} else {
	    set mail_log_id [db_string mail_log "select log_id from acs_mail_log where to_addr = :email and context_id = :project_id limit 1" -default ""]
    }

	set already_logged_p [db_string already_invited "select 1 from flyhh_event_participant_invitation where email = :email and event_id = :event_id" -default 0]

	if {!$already_logged_p} {
	    ds_comment "Log:: $email :: $event_id :: $mail_log_id"
	
	    db_dml log_invite "insert into flyhh_event_participant_invitation (email,event_id,mail_log_id) values (:email,:event_id,:mail_log_id)"
	}
    }
}

asdas

