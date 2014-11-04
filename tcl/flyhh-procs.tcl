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
# @last-modified 2014-11-02
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
# @last-modified 2014-11-02
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
        -body $body \
        -mime_type $mime_type \
        -object_id $participant_id

    # TODO: record confirmation_mail_sent_p flag in participants table and confirmation_mail_date
    # and consider storing the delivery date (we need to figure out how to use callbacks for that)

}

proc ::flyhh::create_company_if { user_id company_name {existing_user_p false}} {

    if { $existing_user_p } {

        set company_path [regsub -all {[^a-zA-Z0-9]} [string trim [string tolower $company_name]] "_"]

        set sql "select company_id from im_companies where company_path = :company_path" 
        set company_id [db_string company $sql -default ""]

        if { $company_id eq {} } {

            set sql "select company_id from im_companies where company_name = :company_name" 
            set company_id [db_string company_id $sql -default ""]

            set sql "update im_companies set company_path = :company_path where company_id = :company_id"
            db_dml update $sql

        }

    } else {

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


ad_proc ::flyhh::create_user_if {
    email 
    first_names 
    last_name 
    company_idVar 
    person_idVar
} {
    @author Neophytos Demetriou (neophytos@azet.sk)
    @creation-date 2014-11-04
    @last-modified 2014-11-04
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
            error "[lang::message::lookup "" intranet-contacts.Error_creating_user "Error creating new user"]:
            [lang::message::lookup "" intranet-contacts.Error_creating_user_status "Status"]: $creation_status
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

    return $invoice_id

}


ad_proc ::flyhh::set_participant_status { 
    -participant_id 
    -from_status 
    -to_status
} {
    @author Neophytos Demetriou (neophytos@azet.sk)
    @creation-date 2014-11-04
    @last-modified 2014-11-04
} {

    set sql "
        select category_id 
        from im_categories 
        where category_type='Flyhh - Event Registration Status'
        and category=:to_status
    "
    set to_status_id [db_string pending_payment_status_id $sql]

    set sql "
        select category_id 
        from im_categories 
        where category_type='Flyhh - Event Registration Status'
        and category=:from_status
    "
    set from_status_id [db_string confirmed_status_id $sql]

    set sql "
        update flyhh_event_participants set event_participant_status_id=:to_status_id 
        where participant_id=:participant_id and event_participant_status_id=:from_status_id"
    db_dml update_event_participant_status $sql

}
