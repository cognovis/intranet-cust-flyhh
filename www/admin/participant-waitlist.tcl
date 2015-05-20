ad_page_contract {

    @author Neophytos Demetriou (neophytos@azet.sk)
    @creation-date 2014-11-12
    @last-modified 2014-11-12

    If a customer registration is cancelled by the project manager (so not automatically by the reminder system) and the
    status is at least pending payment (so we have a confirmation by the customer they want to participate) , create a
    correction invoice which contains refunds as in ::flyhh::record_after_confirmation_edit. 

} {
    participant_id:integer,multiple,notnull
    return_url:trim,notnull
}

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


