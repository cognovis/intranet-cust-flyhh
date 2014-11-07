ad_page_contract {
    Payment Page
} {
    participant_id:integer,notnull
} -validate {

    check_user_is_same -requires {participant_id:integer} {

        ::flyhh::check_user_is_same -participant_id $participant_id

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

}

# The PDF of the new invoice is generated and attached to the financial document.
set invoice_revision_id [intranet_openoffice::invoice_pdf -invoice_id $new_invoice_id]

# An E-Mail is send to the participant with the PDF attached and the payment 
# information similar to what is displayed on the Web site.
::flyhh::send_invoice_mail -invoice_id $new_invoice_id    

# The webpage should display the information what has been provided with the registration,
# a link to the PDF invoice for review, the total amount, the due date (based on the time 
# the link was clicked and the payment terms).

set invoice_pdf_link "invoice-pdf/invoice_${participant_id}_${new_invoice_id}_${invoice_revision_id}.pdf"

