namespace eval ::flyhh {;}

proc ::flyhh::match_name_email {text nameVar emailVar} {
#
# Simple parsing function to extract name and email from
# a string of the following forms:
#
# firstname lastname email
# firstname lastname
# email
#
# @creation-user Neophytos Demetriou (neophytos@azet.sk)
# @creation-date 2014-10-30
# @last-modified 2014-11-10
#

    upvar $nameVar name
    upvar $emailVar email

    set text [string trim $text]
    set name ""
    set email ""

    set email_re {([^\s\.]+@[^\s\.]+\.(?:[^\s\.]+)+)}
    set name_re {((?:[^\s]+\s+)+[^\s]+)}
    set name_email_re "${name_re}\\s+${email_re}"

    if { ![regexp -- $name_email_re $text _dummy_ name email] } {
        if { ![regexp -- $email_re $text _dummy_ email] } {
            if { ![regexp -- $name_re $text _dummy_ name] } {
                return false
            }
        }
    }
    set name [string trim $name " "]

    ns_log notice ">>>> name=$name email=$email"
    
    return true

}

proc ::flyhh::send_confirmation_mail {participant_id} {
#
# @creation-user Neophytos Demetriou (neophytos@azet.sk)
# @creation-date 2014-11-02
# @last-modified 2014-11-10
#

    set sql "
        select 
            *, 
            party__email(person_id) as email, 
            person__name(person_id) as name,
            flyhh_event__name_from_project_id(project_id) as event_name,
            im_name_from_id(accommodation) as accommodation,
            im_name_from_id(food_choice) as food_choice,
            im_name_from_id(bus_option) as bus_option
        from flyhh_event_participants 
        where participant_id=:participant_id
    "
    db_1row participant_info $sql

    # The payment page checks that the logged in user and the participant_id are 
    # the same (so you can’t confirm on behalf of someone else). We could make it
    # more flexible by having a unique token that signs the link we sent out.
    #
    set current_location [util_current_location]
    set link_to_payment_page "${current_location}/flyhh/payment?participant_id=${participant_id}"
    set from_addr "noreply-${participant_id}@flying-hamburger.de"
    set to_addr ${email}
    set mime_type "text/plain"
    set subject "Event Registration Confirmation for ${name}"
    set body "
Hi ${name},

We have reserved a spot for you for \"${event_name}\".

Here's what you have signed up for:
Accommodation: ${accommodation}
Food Choice: ${food_choice}
Bus Option: ${bus_option}

To complete the registration, please proceed with payment at the following page:
${link_to_payment_page}
"

    acs_mail_lite::send \
        -from_addr $from_addr \
        -to_addr $to_addr \
        -subject $subject \
        -body $body \
        -mime_type $mime_type \
        -object_id $participant_id

    # TODO: record confirmation_mail_sent_p flag in participants table and confirmation_mail_date
    # and consider storing the delivery date (we need to figure out how to use callbacks for that)

}

proc ::flyhh::create_company_if { user_id company_name {existing_user_p false}} {

    set company_id ""
    if { $existing_user_p } {

        set company_path [regsub -all {[^a-zA-Z0-9]} [string trim [string tolower $company_name]] "_"]

        set sql "select company_id from im_companies where company_path = :company_path" 
        set company_id [db_string company_id_by_path $sql -default ""]

        if { $company_id eq {} } {

            set sql "select company_id from im_companies where company_name = :company_name" 
            set company_id [db_string company_id_by_name $sql -default ""]

            if { $company_id ne {} } {
                set sql "update im_companies set company_path = :company_path where company_id = :company_id"
                db_dml update $sql
            }

        }

    } 
    
    if { $company_id eq {} } {

        set company_id [im_new_object_id]
        set office_id [im_new_object_id]
        
        set default_company_type_id [im_company_type_customer]
        set company_type_id $default_company_type_id
        set company_status_id [im_company_status_active]
        regsub -all {[^a-zA-Z0-9]} [string trim [string tolower $company_name]] "_" company_path
        set office_path "${company_path}_home"
        
        set main_office_id [im_office::new \
                                -office_name        "$company_name Home" \
                                -company_id         $company_id \
                                -office_type_id     [im_office_type_main] \
                                -office_status_id   [im_office_status_active] \
                                -office_path        $office_path]

        # add users to the office as 
        set role_id [im_biz_object_role_office_admin]
        im_biz_object_add_role $user_id $main_office_id $role_id
        
        # Now create the company with the new main_office:
        set company_id [im_company::new \
                            -company_id             $company_id \
                            -company_name           $company_name \
                            -company_path           $company_path \
                            -main_office_id         $main_office_id \
                            -company_type_id        $company_type_id \
                            -company_status_id      $company_status_id]
                
        # add users to the company as key account
        set role_id [im_biz_object_role_key_account]
        im_biz_object_add_role $user_id $company_id $role_id
        db_dml update_primary_contact "update im_companies set primary_contact_id = :user_id where company_id = :company_id and primary_contact_id is null"

    }

    return $company_id
}

ad_proc ::flyhh::set_user_contact_info {
    {-user_id ""}
    {-email ""}
    {-cell_phone ""}
    {-ha_line1 ""}
    {-ha_line2 ""}
    {-ha_city ""}
    {-ha_state ""}
    {-ha_postal_code ""}
    {-ha_country_code ""}
} {
    @author Neophytos Demetriou (neophytos@azet.sk)
    @creation-date 2014-11-04
    @last-modified 2014-11-04
} {

    if { $user_id eq {} && $email ne {} } {
        set sql "select party_id from parties where email=:email"
        set user_id [db_string user_id $sql]
    }

    set sql "select true from users_contact where user_id=:user_id"
    set found_p [db_string found_user_contact_info $sql -default "false"]

    if { !$found_p } {

        set sql "
            insert into users_contact (
                user_id,
                cell_phone,
                ha_line1,
                ha_line2,
                ha_city,
                ha_state,
                ha_postal_code,
                ha_country_code
            ) values ( 
                :user_id,
                :cell_phone,
                :ha_line1,
                :ha_line2,
                :ha_city,
                :ha_state,
                :ha_postal_code,
                lower(:ha_country_code)
            )
        "
        db_dml insert_user_contact_info $sql

    } else {

        set sql "
            update users_contact set
                cell_phone=:cell_phone,
                ha_line1=:ha_line1,
                ha_line2=:ha_line2,
                ha_city=:ha_city,
                ha_state=:ha_state,
                ha_postal_code=:ha_postal_code,
                ha_country_code=lower(:ha_country_code)
            where user_id=:user_id
        "
        db_dml update_user_contact_info $sql

    }

}

ad_proc ::flyhh::mc { key default_text } {
    @author Neophytos Demetriou
    @creation-date 2014-11-10
    @last-modified 2014-11-10
} {
    return [::lang::message::lookup "" intranet-cust-flyhh.${key} ${default_text}]
}


ad_proc ::flyhh::create_user_if {
    email 
    first_names 
    last_name 
    company_idVar 
    person_idVar
} {
    @author Neophytos Demetriou (neophytos@azet.sk)
    @creation-date 2014-11-04
    @last-modified 2014-11-10
} {

    if { $company_idVar ne {} } {
        upvar $company_idVar company_id
    }

    if { $person_idVar ne {} } {
        upvar $person_idVar user_id
    }

    set user_id [db_string user_id "select user_id from cc_users where email=:email" -default ""]

    if { $user_id eq {} } {

        set existing_user_p false

        array set creation_info [auth::create_user \
            -first_names $first_names \
            -last_name $last_name \
            -email $email \
            -nologin]

        # A successful creation_info looks like:
        # username zahir@zunder.com account_status ok creation_status ok
        # generated_pwd_p 0 account_message {} element_messages {}
        # creation_message {} user_id 302913 password D6E09A4E9

        set creation_status "error"
        if { [info exists creation_info(creation_status)] } { 
            set creation_status $creation_info(creation_status)
        }

        if { "ok" != [string tolower $creation_status] } {
            error "[::flyhh::mc Error_creating_user "Error creating new user"]:
            [:flyhh::mc Error_creating_user_status "Status"]: $creation_status
            \n$creation_info(creation_message)\n$creation_info(element_messages)
            "
        }

        # Extract the user_id from the creation info
        set user_id $creation_info(user_id)

        # Update creation user to allow the creator to admin the user
        # db_dml update_creation_user_id "
        #    update acs_objects
        #    set creation_user = :current_user_id
        #    where object_id = :user_id
        # "

    } else {

        set existing_user_p true

        set sql "update persons set first_names = :first_names, last_name = :last_name where person_id = :user_id"
        db_dml update_names $sql

    }

    # note that upload-contacts-2.tcl only used the participant's name
    # to generate the company name, we refrain from doing so here to
    # avoid any naming conflicts
    set company_name "$user_id - $first_names $last_name"
    set company_id [::flyhh::create_company_if $user_id $company_name $existing_user_p]

    set new_user_p [expr { !$existing_user_p }]

    return $new_user_p

}


ad_proc ::flyhh::create_purchase_order {
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

    # Intranet Cost Type
    # (3706 = Purchase Order)
    set invoice_type_id "3706"

    return [::flyhh::create_invoice \
                -company_id $company_id \
                -company_contact_id $company_contact_id \
                -participant_id $participant_id \
                -project_id $project_id \
                -payment_method_id $payment_method_id \
                -payment_term_id $payment_term_id \
                -invoice_type_id $invoice_type_id]

}


ad_proc ::flyhh::create_invoice {
    -company_id 
    -company_contact_id 
    -participant_id
    -project_id
    -payment_method_id 
    -payment_term_id
    -invoice_type_id
} {
    @param invoice_type_id Intranet Cost Type (3700 = Customer Invoice, 3702 = Quote, 3706 = Purchase Order)

    @author Neophytos Demetriou (neophytos@azet.sk)
    @creation-date 2014-11-04
    @last-modified 2014-11-04
} {

    set payment_days [ad_decode $payment_term_id "80107" "7" "80114" "14" "80130" "30" "80160" "60" ""]

    set provider_id 8720          ;# Company that provides this service - Us
    set invoice_status_id "3802"  ;# Intranet Cost Status (3800 = Created)
    set invoice_template_id "900" ;# Intranet Cost Template (900 = template.en.adp)

    set sql "select project_cost_center_id from im_projects where project_id=:project_id"
    set cost_center_id [db_string cost_center_id $sql]
    set sql "select cost_center_code from im_cost_centers where cost_center_id = :cost_center_id"
    set cost_center_code [db_string cost_center_code $sql]
    set note "$cost_center_code $participant_id"
    set user_id [ad_conn user_id]
    set peeraddr [ad_conn peeraddr]
    set invoice_nr [im_next_invoice_nr -cost_type_id [im_cost_type_invoice]]
    set invoice_id [db_exec_plsql create_invoice "
        select im_invoice__new (
            null,                       -- invoice_id
            'im_invoice',               -- object_type
            now(),                      -- creation_date 
            :user_id,                   -- creation_user
            :peeraddr,                  -- creation_ip
            null,                       -- context_id
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
            vat_type_id = 42021 
        where cost_id = :invoice_id
     "

    ::flyhh::create_invoice_items \
        -invoice_id $invoice_id \
        -participant_id $participant_id

    return $invoice_id

}


ad_proc ::flyhh::create_invoice_items {
    -invoice_id
    -participant_id
} {
    @author Neophytos Demetriou (neophytos@azet.sk)
} {

    # TODO: turn provider_company_id into a package parameter
    set provider_company_id "8720"

    set sql "
        select
            course,
            accommodation,
            food_choice,
            bus_option
        from flyhh_event_participants
        where participant_id=:participant_id
    "
    db_1row participant_info $sql

    set sort_order 1
    foreach varname {course accommodation food_choice bus_option} {
        set material_id [set $varname]

        if { $material_id eq {} } { continue }

        set sql "
            select material_name, material_uom_id, price 
            from im_materials im inner join im_timesheet_prices itp on (itp.material_id=im.material_id)
            where im.material_id=:material_id
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
            null,
            :invoice_id,
            1,
            :material_uom_id,
            :price,
            'EUR',
            :sort_order,
            null,
            :material_id,
            null,
            '',
            null,
            null
        )" 

        db_dml insert_invoice_items $sql

        incr sort_order

    }

    # Update the total amount
    set sql "
        select 
            sum( round(item_units*price_per_unit,2) + round(item_units*price_per_unit*cb.aux_int1/100,2) )
        from 
            im_invoice_items ii,
            im_categories ca,
            im_categories cb,
            im_materials im 
        where invoice_id = :invoice_id
        and ca.category_id = material_type_id
        and ii.item_material_id = im.material_id
        and ca.aux_int2 = cb.category_id
    "
    set total_amount [db_string total_amount $sql]
    
    set sql "select round(sum(item_units*price_per_unit),2) from im_invoice_items where invoice_id = :invoice_id"
    set total_net_amount [db_string total $sql]
        
    set sql "update im_costs set amount = :total_net_amount where cost_id = :invoice_id"
    db_dml update_invoice $sql

    # intranet_collmex::update_customer_invoice -invoice_id $invoice_id  

}


ad_proc ::flyhh::status_id_from_name {
    status
} {
    @author Neophytos Demetriou (neophytos@azet.sk)
    @creation-date 2014-11-09
    @last-modified 2014-11-09
} {

    set sql "
        select category_id 
        from im_categories 
        where category_type='Flyhh - Event Registration Status'
        and category=:status
    "

    set status_id [db_string status_id $sql]

    return $status_id

}


ad_proc ::flyhh::set_participant_status { 
    {-participant_id:required ""}
    {-to_status:required ""}
    {-from_status ""}
} {
    @author Neophytos Demetriou (neophytos@azet.sk)
    @creation-date 2014-11-04
    @last-modified 2014-11-09
} {

    set to_status_id [::flyhh::status_id_from_name $to_status]

    if { $from_status ne {} } {

        set from_status_id [::flyhh::status_id_from_name $from_status]

        set sql "
            update flyhh_event_participants 
            set event_participant_status_id=:to_status_id 
            where participant_id=:participant_id 
            and event_participant_status_id=:from_status_id
        "

        db_dml update_event_participant_status_if $sql

    } else {

        set sql "
            update flyhh_event_participants 
            set event_participant_status_id=:to_status_id 
            where participant_id=:participant_id
        "

        db_dml update_event_participant_status $sql

    }

}


ad_proc ::flyhh::check_user_is_same {
    -participant_id
} {
    @author Neophytos Demetriou (neophytos@azet.sk)
    @creation-date 2014-11-07
    @last-modified 2014-11-07
} {

    # DISABLE FOR DEBUGGING/DEVELOPMENT PURPOSES
    return

    set user_id [ad_conn user_id]

    set sql "select person_id from flyhh_event_participants where participant_id=:participant_id"
    set participant_person_id [db_string participant_person_id $sql -default ""]
    
    if { ${user_id} ne ${participant_person_id} } { 
        ad_complain "logged in user and participant must be the same"
    }

}

ad_proc ::flyhh::send_invoice_mail {
    -invoice_id
    {-recipient_id ""}
    {-from_addr ""}
    {-cc_addr ""}
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

    if {"" == $from_addr} {
    set from_addr [party::email -party_id $user_id]
    }
    
    # Get the type information so we can get the strings
    set invoice_type_id [db_string type "select cost_type_id from im_costs where cost_id = :invoice_id"]
    
    set recipient_locale [lang::user::locale -user_id $recipient_id]
    set subject [lang::util::localize "#intranet-invoices.invoice_email_subject_${invoice_type_id}#" $recipient_locale]
    set body [lang::util::localize "#intranet-invoices.invoice_email_body_${invoice_type_id}#" $recipient_locale]

    acs_mail_lite::send -to_addr $to_addr -from_addr $from_addr -cc_addr $cc_addr -subject $subject -body $body -file_ids $invoice_revision_id -use_sender

}

ad_proc -private ::flyhh::html2pdf {
    infile
    outfile
} {

    converts a file from html to pdf
    just an interim solution until we figure out
    what to do with intranet-invoices/view

    @author Neophytos Demetriou (neophytos@azet.sk)
} {

    set tmpfile [ns_tmpnam]

    set cmd "/usr/bin/html2ps -o $tmpfile $infile"
    exec -- /bin/sh -c "$cmd || exit 0" 2> /dev/null

    set cmd "/usr/bin/ps2pdf $tmpfile $outfile"
    exec -- /bin/sh -c "$cmd || exit 0" 2> /dev/null

    file delete $tmpfile

}

ad_proc -public ::flyhh::invoice_pdf {
    {-invoice_id:required}
} {
    Generate a PDF for an invoice and saves it as a CR Item

    Copied ::intranet-openoffice::invoice_pdf and modified to handle the fact that
    intranet-invoices/www/view.tcl does not really generate and neither does it 
    return a pdf file, it just returns html.

} {

    # first fetches the invoice through an http request to intranet-invoices/view
    set user_id [im_sysadmin_user_default]
    set expiry_date [db_string current_date "select to_char(sysdate, 'YYYY-MM-DD') from dual"]
    set auto_login [im_generate_auto_login -expiry_date $expiry_date -user_id $user_id]
    # pdf_p does not seem to have any effect on the response, disabled it so that this proc
    # will continue to work regardless of whether intranet-invoices/view is fixed
    set invoice_url [export_vars -base "[ad_url]/intranet-invoices/view" -url {invoice_id user_id expiry_date auto_login {pdf_p 0} {render_template_id 1}}]
    set mime_type "application/pdf"
    set invoice_nr [db_string name "select invoice_nr from im_invoices where invoice_id = :invoice_id"]

    set tmp_htmlfile [ns_tmpnam]
    set tmp_pdffile [ns_tmpnam]

    apm_transfer_file -url $invoice_url -output_file_name $tmp_htmlfile

    # converts html to pdf
    ::flyhh::html2pdf $tmp_htmlfile $tmp_pdffile
    file delete $tmp_htmlfile

    set item_id [content::item::get_id_by_name -name ${invoice_nr}.pdf -parent_id $invoice_id]
    if {$item_id ne ""} {
        set file_revision_id \
            [cr_import_content \
                -item_id $item_id \
                -creation_user $user_id \
                -title "${invoice_nr}.pdf" \
                $invoice_id \
                $tmp_pdffile \
                [file size $tmp_pdffile] \
                "application/pdf" \
                "${invoice_nr}.pdf"]
    } else {
        set file_revision_id \
            [cr_import_content \
                -creation_user $user_id \
                -title "${invoice_nr}.pdf" \
                $invoice_id \
                $tmp_pdffile \
                [file size $tmp_pdffile] \
                "application/pdf" \
                "${invoice_nr}.pdf"]
    }	
    
    content::item::set_live_revision -revision_id $file_revision_id
    return $file_revision_id
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
            participant_id
        from im_costs cst 
        inner join im_payments pay on (pay.cost_id=cst.cost_id)
        inner join flyhh_event_participants reg on (reg.company_id = cst.customer_id and reg.project_id = cst.project_id)
        where payment_id=:payment_id
    "

    set exists_p [db_0or1row check_payment_event $sql]

    if { $exists_p } {

        set cost_status_paid [im_cost_status_paid]

        set cost_status_partially_paid [im_cost_status_partially_paid]

        if { $cost_status_id eq $cost_status_paid } {

            ::flyhh::set_participant_status \
                -participant_id $participant_id \
                -to_status "Registered"
                
        } elseif { $cost_status_id eq $cost_status_partially_paid } {

            ::flyhh::set_participant_status \
                -participant_id $participant_id \
                -to_status "Partially Paid"

        } else {

            ns_log error "expected cost_status_id to be $cost_status_paid or $cost_status_partially_paid but got $cost_status_id"

        }

    }

}

ad_proc ::flyhh::send_invite_partner_mail {
    -participant_id
    -participant_person_name
    -participant_email
    -project_id
    -event_name
    -partner_email
} {

    Invites partner to join an event.

    @author Neophytos Demetriou (neophytos@azet.sk)

} {

    set inviter_text "$participant_person_name $participant_email"
    set event_registration_link [export_vars -base [ad_url]/flyhh/registration {project_id inviter_text}]
    set from_addr "noreply-${participant_id}-[ns_sha1 $partner_email]@flying-hamburger.de"
    set to_addr $partner_email
    set default_text "
@participant_person_name@ (@participant_email@) has registered for the \"@event_name@\"
and would like to have you as his/her partner.

You can register by followining the link below:
@event_registration_link;noquote@
"
    set msg [::flyhh::mc Partner_Mail_Body $default_text]
    set body [eval [template::adp_compile -string $msg]]
    set mime_type text/plain
    set subject [:flyhh::mc Partner_Mail_Subject "Invitation to register for $event_name"]

    acs_mail_lite::send \
        -from_addr $from_addr \
        -to_addr $to_addr \
        -subject $subject \
        -body $body \
        -mime_type $mime_type \
        -object_id $participant_id


    set sql "
        update flyhh_event_participants
        set partner_reminder_sent=now()
        where participant_id = :participant_id
    "

    db_dml partner_reminder_sent $sql

}

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
    @last-modified 2014-11-10
} {

    ns_log notice "--->>> Flyhh Reminder System: $key for $participant_person_name sent to $to_addr"

    set column_name ${key}_sent

    # column_name is one of first_reminder_sent, second_reminder_sent, third_reminder_sent
    set subject [eval [template::adp_compile -string [::flyhh::mc ${key}_subject "${key} subject"]]]
    set msg_text "
Hi @participant_person_name@,

This is a reminder that your invoice for @event_name@ is due:
Event Registration Link: @event_registration_link@
Invoice ID: @invoice_id@
Invoice Date: @invoice_date@
Due Date: @due_date@
Amount: @amount@
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
            -object_id $participant_id


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

    # When you submit the registration and the dance partner did not register, send the dance partner an E-Mail (text
    # does not matter now) with a link to the registration for the event and the partner who asked them to join, so this
    # is already pre-filled 

    set sql "
        select 
            participant_id,
            person__name(person_id) as participant_person_name,
            party__email(person_id) as participant_email,
            reg.project_id,
            event_name,
            partner_email
        from flyhh_event_participants reg
        inner join flyhh_events evt on (evt.project_id=reg.project_id)
        inner join acs_objects obj on (obj.object_id=reg.participant_id)
        where partner_email is not null
        and partner_participant_id is null
        and partner_reminder_sent is null
        and creation_date > current_timestamp - '1 day'::interval
    "

    db_foreach unregistered_partner $sql {

        ::flyhh::send_invite_partner_mail \
            -participant_id $participant_id \
            -participant_person_name $participant_person_name \
            -participant_email $participant_email \
            -project_id $project_id \
            -event_name $event_name \
            -partner_email $partner_email

    }

    # Seven days after due date: Send a reminder E-Mail to the customer. Text of the reminder is something we configure
    # using language keys, so ideally you would have only a lang key for the subject and the body of the E-Mail. We will
    # need to be able to include the invoice date, invoice number, full amount, due date in the E-Mail as well as the
    # name and a link to the registration.
    #
    # 17 days after due date: Send a second reminder. Same info as above, yet a different E-Mail body and subject will
    # be used
    #
    # 27 days after due date: 
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

                set sql "
                    update im_invoice_items 
                    set price_per_unit = 0.0 - price_per_unit 
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

ad_schedule_proc -thread t 900 ::flyhh::mail_notification_system
