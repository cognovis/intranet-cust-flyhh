namespace eval ::flyhh {;}

ad_proc ::flyhh::create_quote {
    -company_id
    -company_contact_id 
    -participant_id
    -project_id
    -payment_method_id 
    -payment_term_id
} {
    @author Neophytos Demetriou (neophytos@azet.sk)
    @creation-date 2014-11-04
    @last-modified 2014-11-04
} {

    return [::flyhh::create_invoice \
                -company_id $company_id \
                -company_contact_id $company_contact_id \
                -participant_id $participant_id \
                -project_id $project_id \
                -payment_method_id $payment_method_id \
                -payment_term_id $payment_term_id \
                -invoice_type_id [im_cost_type_quote]]

}


ad_proc ::flyhh::create_invoice {
    -company_id 
    -company_contact_id 
    -participant_id
    -project_id
    -payment_method_id 
    -payment_term_id
    -invoice_type_id
    {-delta_items ""}
} {
    @param invoice_type_id Intranet Cost Type 
    3700 = Customer Invoice 
    3702 = Quote 
    3706 = Purchase Order 
    3725 = Customer Invoice Correction

    @author Neophytos Demetriou (neophytos@azet.sk)
    @creation-date 2014-11-04
    @last-modified 2014-11-12
} {

    if { $invoice_type_id eq {3725} && $delta_items eq {} } {
        error "must provide delta items for customer invoice correction"
    }

    set payment_days [ad_decode $payment_term_id "80107" "7" "80114" "14" "80130" "30" "80160" "60" ""]
    set invoice_template [parameter::get -parameter invoice_template -default "InvoiceFlyHH"]
    set locale [lang::user::locale -user_id $company_contact_id]
    set invoice_template "${invoice_template}.${locale}.odt"
    
    set provider_id [im_company_internal]          ;# Company that provides this service - Us
    set invoice_status_id "[im_cost_status_created]"  ;# Intranet Cost Status (3800 = Created)

    set sql "select category_id from im_categories where category = :invoice_template and category_type = 'Intranet Cost Template'"
    set invoice_template_id [db_string invoice_template_id $sql] ;# Intranet Cost Template

    set sql "select project_cost_center_id from im_projects where project_id=:project_id"
    set cost_center_id [db_string cost_center_id $sql]
    set sql "select cost_center_code from im_cost_centers where cost_center_id = :cost_center_id"
    set cost_center_code [db_string cost_center_code $sql]
    set note "$cost_center_code $participant_id"
    set user_id [ad_conn user_id]
    set peeraddr [ad_conn peeraddr]

    set delivery_date [db_string start_date "select start_date from im_projects where project_id = :project_id" -default ""]

    db_transaction {
        set invoice_nr [im_next_invoice_nr -cost_type_id $invoice_type_id]
        set invoice_id [db_exec_plsql create_invoice "
            select im_invoice__new (
                null,                       -- invoice_id
                'im_invoice',               -- object_type
                now(),                      -- creation_date 
                :user_id,                   -- creation_user
                :peeraddr,                  -- creation_ip
                :project_id,                -- context_id
                :invoice_nr,                -- invoice_nr
                :company_id,                -- company_id
                :provider_id,               -- provider_id -- us
                :company_contact_id,        -- company_contact_id
                now(),                      -- invoice_date
                'EUR',                      -- currency
                :invoice_template_id,       -- invoice_template_id
                :invoice_status_id,         -- invoice_status_id
                :invoice_type_id,           -- invoice_type_id
                :payment_method_id,         -- payment_method_id
                :payment_days,              -- payment_days
                0,                          -- amount
                0,                          -- vat
                0,                          -- tax
                :note                       -- note
             )"]

         db_dml update_invoice "
            update im_costs set 
                cost_center_id = :cost_center_id, 
                project_id = :project_id,
                payment_term_id = :payment_term_id, 
                vat_type_id = 42021,
                delivery_date = :delivery_date
            where cost_id = :invoice_id
         "

        if { $invoice_type_id ne {3725} && $delta_items eq {} } {

            set sql "
                select
                    course,
                    accommodation,
                    food_choice,
                    bus_option,
                    partner_mutual_p
                from flyhh_event_participants
                where participant_id=:participant_id
            "
            db_1row participant_info $sql

            foreach varname {course accommodation food_choice bus_option} {
                set material_id [set $varname]

                if { $material_id eq {} } { continue }

                lappend delta_items [list 1.0 1.0 $material_id]
            }
            
            if {$partner_mutual_p eq "t"} {
                # Qualify for the partner rebate.
                lappend delta_items [list 1.0 1.0 [db_string partner_material_id "select material_id from im_materials where lower(material_nr) = 'partner'"]]
            }
        }

        ::flyhh::create_invoice_items \
            -invoice_id $invoice_id \
            -project_id $project_id \
            -delta_items $delta_items

        set rel_id [db_exec_plsql create_rel "
            select acs_rel__new (
                 null,             -- rel_id
                 'relationship',   -- rel_type
                 :project_id,      -- object_id_one
                 :invoice_id,      -- object_id_two
                 null,             -- context_id
                 null,             -- creation_user
                 null             -- creation_ip
            )"]

    }


    return $invoice_id

}


ad_proc ::flyhh::create_invoice_items {
    -invoice_id
    -project_id
    {-delta_items ""}
} {
    @author Neophytos Demetriou (neophytos@azet.sk)
    @creation-date 2014-11-09
    @last-modified 2014-11-11
} {

    set provider_company_id [parameter::get -parameter provider_company_id -default "8720"]


    set sort_order 1
    foreach item $delta_items {
        foreach {item_units percent_price item_material_id} $item break

        # if item_material_id there is nothing to credit or debit
        # and thus we continue with the rest of the items
        if { $item_material_id eq {} } {continue}

        set sql "
            select material_name, material_uom_id, :percent_price * price  as price_per_unit
            from im_materials im inner join im_timesheet_prices itp on (itp.material_id=im.material_id)
            where im.material_id=:item_material_id
            and company_id = :provider_company_id
            limit 1
        "

        db_1row class_material $sql

        set item_id [db_nextval "im_invoice_items_seq"]
        set sql "
        insert into im_invoice_items (
            item_id, 
            item_name,
            project_id,
            invoice_id,
            item_units,
            item_uom_id,
            price_per_unit,
            currency,
            sort_order,
            item_type_id,
            item_material_id,
            item_status_id, 
            description,
            task_id,
            item_source_invoice_id
        ) values (
            :item_id,
            :material_name,
            :project_id,
            :invoice_id,
            :item_units,
            :material_uom_id,
            :price_per_unit,
            'EUR',
            :sort_order,
            null,
            :item_material_id,
            null,
            '',
            null,
            null
        )" 

        db_dml insert_invoice_items $sql

        incr sort_order

    }

    # Update the total net amount

    set sql "select round(sum(item_units*price_per_unit),2) from im_invoice_items where invoice_id = :invoice_id"
    set total_net_amount [db_string total $sql]

    set sql "update im_costs set amount = :total_net_amount where cost_id = :invoice_id"
    db_dml update_invoice $sql

    # intranet_collmex::update_customer_invoice -invoice_id $invoice_id  

}

ad_proc ::flyhh::send_invoice_mail {
    -invoice_id
    -from_addr
    {-recipient_id ""}
    {-cc_addr ""}
    -project_id
} {

    Copied im_invoice_send_invoice_mail and modified it in two ways:
    a) queue the message as opposed to sending it immediately
    b) check if the invoice pdf exists before generating a new one

} {

    set invoice_revision_id [::flyhh::invoice_pdf -invoice_id $invoice_id]

    set user_id [ad_conn user_id]
    if {"" == $recipient_id} {
        set recipient_id [db_string company_contact_id "select company_contact_id from im_invoices where invoice_id = :invoice_id" -default $user_id]
    } 

    db_1row get_recipient_info "select first_names, last_name, email as to_addr from cc_users where user_id = :recipient_id"
    db_1row event_info "select project_cost_center_id, p.project_id, event_name, event_url, event_email, facebook_event_url,facebook_orga_url from flyhh_events f, im_projects p where p.project_id = :project_id and p.project_id = f.project_id"

    # Get the type information so we can get the strings
    set invoice_type_id [db_string type "select cost_type_id from im_costs where cost_id = :invoice_id"]

    set recipient_locale [lang::user::locale -user_id $recipient_id]
    set subject "[lang::util::localize "#intranet-cust-flyhh.invoice_email_subject#" $recipient_locale]"
    set body "[lang::util::localize "#intranet-cust-flyhh.invoice_email_body#" $recipient_locale]"

    acs_mail_lite::send -send_immediately -to_addr $to_addr -from_addr $from_addr -cc_addr $cc_addr -subject $subject -body $body -file_ids $invoice_revision_id -use_sender -object_id $project_id -mime_type "text/html"

}

ad_proc -public ::flyhh::invoice_pdf {
    {-invoice_id:required}
} {
    Generate a PDF for an invoice and saves it as a CR Item

} {
    db_1row invoice_info "select invoice_nr,last_modified from im_invoices,acs_objects where invoice_id = :invoice_id and invoice_id = object_id"

    set invoice_item_id [content::item::get_id_by_name -name "${invoice_nr}.pdf" -parent_id $invoice_id]

    if {"" == $invoice_item_id} {
        set invoice_revision_id [intranet_openoffice::invoice_pdf -invoice_id $invoice_id]
    } else {
        set invoice_revision_id [content::item::get_best_revision -item_id $invoice_item_id]

        # Check if we need to create a new revision
        if {[db_string date_check "select 1 from acs_objects where object_id = :invoice_revision_id and last_modified < :last_modified" -default 0]} {
            set invoice_revision_id [intranet_openoffice::invoice_pdf -invoice_id $invoice_id]
        }
    }

    return $invoice_revision_id
}


ad_proc -public -callback im_payment_after_create -impl intranet-cust-flyhh {
    {-payment_id:required ""}
    {-payment_method_id ""}
} {
    @author Neophytos Demetriou (neophytos@azet.sk)
} {

    set sql "
        select 
            cst.cost_id,
            cst.cost_status_id,
            cst.paid_amount,
            cst.amount as invoice_amount,
            cst.amount - cst.paid_amount as open_amount,
            cst.cost_name as invoice_nr,
            cst.currency,
            pay.amount as payment_amount,
            reg.participant_id,
            p.email as to_addr,
            p.party_id,
            e.event_email as from_addr,
            e.event_name,
            e.project_id
        from im_costs cst 
        inner join im_payments pay on (pay.cost_id=cst.cost_id)
        inner join flyhh_event_participants reg on (reg.company_id = cst.customer_id and reg.project_id = cst.project_id)
        inner join flyhh_events e on (e.project_id = cst.project_id)
        inner join parties p on (reg.person_id = p.party_id)
        where payment_id=:payment_id
        and event_participant_status_id not in ([flyhh::status::cancelled],[flyhh::status::refused],[flyhh::status::waiting_list])
    "

    set exists_p [db_0or1row check_payment_event $sql]

    if { $exists_p } {


        set cost_status_paid [im_cost_status_paid]

        set cost_status_partially_paid [im_cost_status_partially_paid]
        
        # Format the amounts
        set locale [lang::user::site_wide_locale -user_id $party_id]
        set payment_amount_pretty [lc_numeric [im_numeric_add_trailing_zeros [expr $payment_amount+0] 2] "" $locale]
        set paid_amount_pretty [lc_numeric [im_numeric_add_trailing_zeros [expr $paid_amount+0] 2] "" $locale]
        set open_amount_pretty [lc_numeric [im_numeric_add_trailing_zeros [expr $open_amount+0] 2] "" $locale]

	set token [ns_sha1 "${participant_id}${project_id}"]
	set invoice_url [export_vars -base "[ad_url]/flyhh/invoice" -url {participant_id token}]
        if { $cost_status_id eq $cost_status_paid } {

            ::flyhh::set_participant_status \
                -participant_id $participant_id \
                -to_status "Registered"
                
            # Mail the user he is fully registered
            set subject "[_ intranet-cust-flyhh.payment_full_subject]"
            set body "[_ intranet-cust-flyhh.payment_full_body]"

        } elseif { $cost_status_id eq $cost_status_partially_paid || $paid_amount > 0 } {

            ::flyhh::set_participant_status \
                -participant_id $participant_id \
                -to_status "Partially Paid"
            
            # Mail the user he is fully registered
            set subject "[_ intranet-cust-flyhh.payment_part_subject]"
            set body "[_ intranet-cust-flyhh.payment_part_body]"
        } else {

            set to_addr ""
            ns_log error "expected cost_status_id to be $cost_status_paid or $cost_status_partially_paid but got $cost_status_id"

        }
        
        if {$to_addr ne ""} {
            acs_mail_lite::send \
            -send_immediately \
            -from_addr $from_addr \
            -to_addr $to_addr \
            -subject $subject \
            -body $body \
            -mime_type "text/html" \
            -object_id $project_id        
        }
    }

}

# ---------------------------------------------------------------
# Reminder system
# ---------------------------------------------------------------


ad_proc ::flyhh::send_invoice_reminder {
    -key 
    -to_addr
    -participant_id
    -participant_person_name
    -invoice_date
    -invoice_id
    -amount
    -due_date
    -event_name
    -event_registration_link
} {
    @author Neophytos Demetriou (neophytos@azet.sk)
    @creation-date 2014-11-10
    @last-modified 2014-11-11
} {

    ns_log notice "--->>> Flyhh Reminder System: $key for $participant_person_name sent to $to_addr"

    set column_name ${key}_sent

    # column_name is one of first_reminder_sent, second_reminder_sent, third_reminder_sent
    set subject [eval [template::adp_compile -string [::flyhh::mc ${key}_subject "${key} subject"]]]
    set msg_text "
Hi @participant_person_name@,

This is a reminder that your invoice for @event_name@ is due:
Event Registration Link: @event_registration_link;noquote@
Invoice ID: @invoice_id@
Invoice Date: @invoice_date@
Due Date: @due_date@
Amount: @amount@

(@msg_key@)
    "
    set body [eval [template::adp_compile -string [::flyhh::mc ${key}_body ${msg_text}]]]
    set from_addr "noreply-${participant_id}@flying-hamburder.de"
    set mime_type text/plain

    db_transaction {

        acs_mail_lite::send \
            -from_addr $from_addr \
            -to_addr $to_addr \
            -subject $subject \
            -body $body \
            -mime_type $mime_type \
            -object_id $project_id


        set sql "
            update flyhh_event_participants
            set $column_name = now()
            where participant_id = :participant_id
        "

        db_dml update_participant_reminder_info $sql

    }

}

ad_proc ::flyhh::mail_notification_system {} {

    Scheduled proc that sends customer payment reminders and asks partners to join an event.

    @author Neophytos Demetriou (neophytos@azet.sk)
    @creation-date 2014-11-10
    @last-modified 2014-11-10

} {


    # Seven days after due date: Send a reminder E-Mail to the customer. Text of the reminder is something we configure
    # using language keys, so ideally you would have only a lang key for the subject and the body of the E-Mail. We will
    # need to be able to include the invoice date, invoice number, full amount, due date in the E-Mail as well as the
    # name and a link to the registration.
    #
    # 17 days after due date: Send a second reminder. Same info as above, yet a different E-Mail body and subject will
    # be used
    #
    # 27 days after due date:?
    # (a) In case we have a partial payment, send an E-Mail to the Project Manager to have a chat with the customer
    # (b) In case we have no payment, create a correction invoice. This is basically an invoice copy with type invoice
    # correction and the same amounts in negative values. Mark the registration as cancelled.

    set cost_status_partially_paid [im_cost_status_partially_paid]
    set cost_status_paid [im_cost_status_paid]

    set first_reminder_interval [parameter::get -parameter first_reminder_interval -default "7 days"]
    set second_reminder_interval [parameter::get -parameter second_reminder_interval -default "17 days"]
    set third_reminder_interval [parameter::get -parameter third_reminder_interval -default "27 days"]

    set sql "
        select
            reg.participant_id,
            person__name(reg.person_id) as participant_person_name,
            party__email(reg.person_id) as participant_email,
            evt.event_name,
            prj.project_id,
            coalesce(party__email(prj.project_lead_id),'prjmgr@examle.com') as project_lead_email,
            cst.cost_id as invoice_id,
            cst.cost_status_id,
            cst.effective_date as invoice_date,
            cst.effective_date::date + payment_days as due_date,
            cst.amount,
            (inv_first_reminder_sent is null and effective_date < current_timestamp - '${first_reminder_interval}'::interval) as first_reminder_p,
            (inv_second_reminder_sent is null and effective_date < current_timestamp - '${second_reminder_interval}'::interval) as second_reminder_p,
            (inv_third_reminder_sent is null and effective_date < current_timestamp - '${third_reminder_interval}'::interval) as third_reminder_p
        from flyhh_event_participants reg
        inner join flyhh_events evt on (evt.project_id = reg.project_id)
        inner join im_projects prj on (prj.project_id = reg.project_id)
        inner join im_costs cst on (cst.cost_id = reg.invoice_id)
        where reg.invoice_id is not null
        and cst.cost_status_id != :cost_status_paid
        and cst.effective_date < current_timestamp - '7 days'::interval
    "

    db_foreach unpaid_invoice $sql {

        set to_addr $participant_email

        set event_registration_link [export_vars -base "[ad_url]/flyhh/registration" {project_id participant_id}]

        if { $first_reminder_p } {

            set msg_key "inv_first_reminder"

        } elseif { $second_reminder_p } {

            set msg_key "inv_second_reminder"

        } else {

            set msg_key "inv_third_reminder"

            if { $cost_status_id ne $cost_status_partially_paid } {

                ## Create correction invoice

                # Intranet Cost Type
                # (3725 = Customer Invoice Correction)
                set target_cost_type_id [im_cost_type_correction_invoice] 

                set new_invoice_id \
                    [im_invoice_copy_new \
                        -source_invoice_ids $invoice_id \
                        -target_cost_type_id $target_cost_type_id]

                # new_invoice_id must be set to the same amount in negative values

                # set sql "update im_invoice_items set price_per_unit = 0.0 - price_per_unit where invoice_id=:new_invoice_id"

                set sql "
                    update im_invoice_items 
                    set item_units = 0.0 - item_units
                    where invoice_id=:new_invoice_id
                "

                db_dml update_new_invoice_amount $sql

                # Update the total amount

                set sql "select round(sum(item_units*price_per_unit),2) from im_invoice_items where invoice_id = :invoice_id"
                set total_net_amount [db_string total $sql]

                set sql "update im_costs set amount = :total_net_amount where cost_id = :invoice_id"
                db_dml update_invoice $sql

                ## Mark the registration as cancelled

                ::flyhh::set_participant_status \
                    -participant_id $participant_id \
                    -to_status "Cancelled"

                set to_addr ${project_lead_email}

            }

        }

        ::flyhh::send_invoice_reminder \
            -key $msg_key \
            -to_addr $to_addr \
            -participant_id $participant_id \
            -participant_person_name $participant_person_name \
            -invoice_date $invoice_date \
            -invoice_id $invoice_id \
            -amount $amount \
            -due_date $due_date \
            -event_name $event_name \
            -event_registration_link $event_registration_link

    }

}
