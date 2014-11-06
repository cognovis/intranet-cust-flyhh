ad_page_contract {
    Payment Page
} {
    participant_id:integer,notnull
} -validate {

    check_user_is_same -requires {participant_id:integer} {

# DISABLE FOR DEBUGGING/DEVELOPMENT PURPOSES
return

        set user_id [ad_conn user_id]

        set sql "select person_id from flyhh_event_participants where participant_id=:participant_id"
        set participant_person_id [db_string participant_person_id $sql -default ""]
        
        if { ${user_id} ne ${participant_person_id} } { 
            ad_complain "logged in user and participant must be the same"
        }

    }

}

db_transaction {

    ::flyhh::set_participant_status \
        -participant_id ${participant_id} \
        -from_status "Confirmed" \
        -to_status "Pending Payment"

    # When the customer confirms he wants to participate in the event,
    # we create an invoice from the purchase order

    set sql "select order_id as purchase_order_id from flyhh_event_participants where participant_id=:participant_id"
    db_1row participant_info $sql

    # Intranet Cost Type
    # (3700 = Customer Invoice)
    set target_cost_type_id "3700"
    set new_invoice_id [im_invoice_copy_new -source_invoice_ids $purchase_order_id -target_cost_type_id $target_cost_type_id]
    
    # Intranet Cost Status
    # (3804 = Outstanding)
    set new_status_id "3804"
    db_dml update_cost_status "update im_costs set cost_status_id = :new_status_id where cost_id = :purchase_order_id"

    # The PDF of the new invoice is generated and attached to the financial document.
    # An E-Mail is send to the participant with the PDF attached and the payment 
    # information similar to what is displayed on the Web site.
    im_invoice_send_invoice_mail -invoice_id $new_invoice_id

}

# NOT IMPLEMENTED YET
ns_return 200 text/plain "not implemented yet"
