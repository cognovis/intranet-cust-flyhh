ad_page_contract {

    @author Neophytos Demetriou (neophytos@azet.sk)
    @creation-date 2014-11-12
    @last-modified 2014-11-12

    If a customer registration is cancelled by the project manager (so not automatically by the reminder system) and the
    status is at least pending payment (so we have a confirmation by the customer they want to participate) , create a
    correction invoice which contains refunds as in ::flyhh::record_after_confirmation_edit.†

} {
    participant_id:integer,multiple,notnull
    return_url:trim,notnull
}


    foreach id $participant_id {
        
        # Create the correction invoice
        set sql "
            select 
                ep.project_id,
                ep.person_id,
                ep.invoice_id,
                ep.event_participant_status_id,
                ep.course
            from flyhh_event_participants ep
            where participant_id=:participant_id
        "
        
        db_1row participant_info $sql
        set paid_amount 0
        set cancellation_fee 0
        
        if {$invoice_id ne ""} {
            # If the invoice is partially paid, we only pay back up to the initial amount. 
            # If no money way paid, we do a full invoice correction
            db_1row amount "select amount,currency from im_costs where cost_id = :invoice_id"
        
            # Find out if the participant get's money back
            set paid_amount [db_string paid_amount "select sum(amount) from im_payments where cost_id = :invoice_id"]
        
    
            if {$event_participant_status_id != [flyhh::status::pending_payment]} {
                # Round the due now
                set cancellation_fee [expr round($amount*0.03)]
                set cancellation_fee [expr $cancellation_fee * 10]
            }
            
            # Copy the invoice without a callback
            set cancellation_invoice_id [im_invoice_copy_new -source_invoice_ids $invoice_id -target_cost_type_id [im_cost_type_correction_invoice] -no_callback -cancellation]
            
            # ---------------------------------------------------------------
            # Update and add the cancellation_fee if necessary
            # ---------------------------------------------------------------
            
            if {$cancellation_fee > 0} {
                set item_id [db_nextval "im_invoice_items_seq"]
                
                db_dml insert_cancellation_fee "
                    INSERT INTO im_invoice_items (
                            item_id, item_name,
                            project_id, invoice_id,
                            item_units, item_uom_id,
                            price_per_unit, currency,
                            sort_order,item_material_id
                    ) values (:item_id, 'Cancellation Fee',
                            :project_id, :cancellation_invoice_id,
                            1, [im_uom_unit],
                            :cancellation_fee, :currency,
                            99,:course)
                "
            } 
            
            # Generate the PDF for the invoice
            # set cancellation_invoice_revision_id [::flyhh::invoice_pdf -invoice_id $cancellation_invoice_id]


            im_invoice_update_rounded_amount \
                -invoice_id $cancellation_invoice_id 

            # Mark that we have cancelled the invoice
            im_audit -object_type "im_invoice" -object_id $cancellation_invoice_id -action after_create -status_id [im_cost_status_paid] -type_id 3725
        }

        set to_status_id [::flyhh::status_id_from_name "Cancelled"]

        db_dml update_status "
            update flyhh_event_participants 
            set event_participant_status_id=:to_status_id 
            where participant_id=:id
        "
        
        # ---------------------------------------------------------------
        # Send a cancellation E-Mail
        # ---------------------------------------------------------------
        
        if {$paid_amount > $cancellation_fee} {
            set difference [expr {$paid_amount - $cancellation_fee}]
            set invoice_text "Please send us your account details so we can wire you the difference of $difference EUR (cancellation fee is $cancellation_fee EUR until August 1st)." 
        } elseif {$paid_amount > 0} {
            set invoice_text "For your information: According to our Terms & Conditions the cancellation fee equals the first payment installment therefore we won't transfer your initial payment back to you."
        } else {
            set invoice_text ""
        }
        
        db_1row get_recipient_info "select first_names, last_name, email as to_addr, person_id from cc_users where user_id = :person_id"
        db_1row event_info "select project_cost_center_id, p.project_id, event_name, event_url, event_email, facebook_event_url,facebook_orga_url from flyhh_events f, im_projects p where p.project_id = :project_id and p.project_id = f.project_id"
        
        set body "<table align=center width='80%' cellpadding=1 cellspacing=2 border=0>
            <tr><td colspan=3>
            Dear $first_names,
            <p>
            We hereby confirm the cancellation of your $event_name participation.<br />
            <br />
            $invoice_text
            </p>
            </td></tr>
             <tr><td colspan=3>We hope to see you next year at the castle! <br /> <br />All the best<br />Anna & Malte & Ulrike</td></tr></table>
             "
        
        set subject "Cancellation for $event_name"
        
        acs_mail_lite::send -send_immediately -to_addr $to_addr -from_addr $event_email -subject $subject -body $body -use_sender -object_id $project_id -mime_type "text/html"

    }


ad_returnredirect $return_url


