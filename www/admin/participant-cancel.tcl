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

        ::flyhh::set_participant_status \
            -participant_id $id \
            -to_status "Cancelled"

        # ::flyhh::send_cancellation_mail $id

    }

}


ad_returnredirect $return_url


