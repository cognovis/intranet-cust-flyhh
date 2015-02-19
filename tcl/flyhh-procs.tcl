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
# @last-modified 2014-11-11
#

    set sql "
        select 
            *, 
            party__email(person_id) as email, 
            person__name(person_id) as name,
            im_name_from_id(course) as course,
            im_name_from_id(accommodation) as accommodation,
            im_name_from_id(food_choice) as food_choice,
            im_name_from_id(bus_option) as bus_option
        from flyhh_event_participants p, flyhh_events e
        where participant_id=:participant_id
        and e.project_id = p.project_id
    "
    db_1row participant_info $sql

    # The payment page checks that the logged in user and the participant_id are 
    # the same (so you can?t confirm on behalf of someone else). We could make it
    # more flexible by having a unique token that signs the link we sent out.
    #
    
    set token [ns_sha1 "${participant_id}${project_id}"]

    set link_to_payment_page "[export_vars -base "[ad_url]/flyhh/payment" -url {participant_id token}]"
    set from_addr "$event_email"
    set to_addr ${email}
    set mime_type "text/html"
    set subject "[_ intranet-cust-flyhh.confirm_mail_subject]"
    set body "
Hi $name,
<p>
<#_ We have reserved a spot for you at %event_name%.#>
</p>
<#_ Here's what you have signed up for:#>
<ul>
"

if {$course ne ""} {
    append body "<li>[_ intranet-cust-flyhh.Course]: $course</li>"
}
if {$accommodation ne ""} {
    append body "<li>[_ intranet-cust-flyhh.Accommodation]: $accommodation</li>"
}
if {$food_choice ne ""} {
    append body "<li>[_ intranet-cust-flyhh.Food_Choice]: $food_choice</li>"
}
if {$bus_option ne ""} {
    append body "<li>[_ intranet-cust-flyhh.Bus]: $bus_option</li>"
}

append body "
</ul>
<#_ To complete the registration and reserve your spot, please click below for the payment information:#>
<p>
<a href='@link_to_payment_page;noquote@'><#_ Payment Information#></a>
</p>
}]]

    acs_mail_lite::send \
        -send_immediately \
        -from_addr $from_addr \
        -to_addr $to_addr \
        -subject $subject \
        -body $body \
        -mime_type $mime_type \
        -object_id $project_id

    # Update the quote to mark the E-Mail has been send.
    db_dml update_quote_status "update im_costs set cost_status_id = [im_cost_status_outstanding] where cost_id = :quote_id"
    
    # TODO: record confirmation_mail_sent_p flag in participants table and confirmation_mail_date
    # and consider storing the delivery date (we need to figure out how to use callbacks for that)

}

ad_proc ::flyhh::create_company_if { 
    user_id
    company_name
    {existing_user_p false}
} {
    @creation-user Neophytos Demetriou (neophytos@azet.sk)
    @creation-date 2014-10-30
    @last-modified 2014-11-11
} {

    set company_path "${user_id}_[regsub -all {[^a-zA-Z0-9]} [string trim [string tolower $company_name]] "_"]"

    set company_id ""
    if { $existing_user_p } {

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
                ha_city,
                ha_state,
                ha_postal_code,
                ha_country_code
            ) values ( 
                :user_id,
                :cell_phone,
                :ha_line1,
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
    if {![lang::message::message_exists_p en_US intranet-cust-flyhh.${key}]} {
        lang::message::register en_US intranet-cust-flyhh $key $default_text
    }
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

    set user_id [db_string user_id "select party_id from parties where email=:email" -default ""]

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
            [::flyhh::mc Error_creating_user_status "Status"]: $creation_status
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
    set company_name "$first_names $last_name"
    set company_id [::flyhh::create_company_if $user_id $company_name $existing_user_p]

    set new_user_p [expr { !$existing_user_p }]

    return $new_user_p

}

ad_proc ::flyhh::create_participant {
    -participant_id:required
    -project_id:required
    -email:required
    -first_names:required
    -last_name:required
    -accepted_terms_p:required
    -course:required
    -accommodation:required
    -food_choice:required
    -bus_option:required
    -level:required
    -lead_p:required 
    -payment_type:required
    -payment_term:required
    -partner_text:required
    -roommates_text:required
    -cell_phone:required
    -ha_line1:required
    -ha_city:required
    -ha_state:required
    -ha_postal_code:required
    -ha_country_code:required
} {
    @author Neophytos Demetriou (neophytos@azet.sk)
    @creation-date 2014-11-11
    @last-modified 2014-11-11
} {

    set creation_ip [ad_conn peeraddr]

    ::flyhh::match_name_email $partner_text partner_name partner_email

    db_transaction {

        set new_user_p [::flyhh::create_user_if $email $first_names $last_name company_id person_id]

        ::flyhh::set_user_contact_info \
            -user_id $person_id \
            -cell_phone $cell_phone \
            -ha_line1 $ha_line1 \
            -ha_city  $ha_city \
            -ha_state $ha_state \
            -ha_postal_code $ha_postal_code \
            -ha_country_code $ha_country_code

        set sql "
            update im_offices set
                phone=:cell_phone,
                address_line1=:ha_line1,
                address_city=:ha_city,
                address_state=:ha_state,
                address_postal_code=:ha_postal_code,
                address_country_code=lower(:ha_country_code)
            where office_id=(select main_office_id from im_companies where company_id=:company_id)
        "
        db_dml update_company_contact_info $sql

        db_exec_plsql insert_participant "select flyhh_event_participant__new(

            :person_id,
            :company_id,

            :participant_id,

            :email,
            :first_names,
            :last_name,
            :creation_ip,

            :project_id,

            :lead_p,
            :partner_text,
            :partner_name,
            :partner_email,
            :accepted_terms_p,

            :course,
            :accommodation,
            :food_choice,
            :bus_option,
            :level,
            
            :payment_type,
            :payment_term

        )"

        set roommates_list [lsearch -all -inline -not [split $roommates_text ",|\t\n\r"] {}]

        foreach roommate_text $roommates_list {

            ::flyhh::match_name_email $roommate_text roommate_name roommate_email

            db_exec_plsql insert_roommate "select flyhh_event_roommate__new(
                :participant_id,
                :project_id,
                :roommate_email,
                :roommate_name
            )"

        }

        db_exec_plsql status_automaton "select flyhh_event_participant__status_automaton(:participant_id)"

    }

}


ad_proc ::flyhh::update_participant {
    -participant_id:required
    -project_id:required
    -email:required
    -first_names:required
    -last_name:required
    -accepted_terms_p:required
    -course:required
    -accommodation:required
    -food_choice:required
    -bus_option:required
    -level:required
    -lead_p:required 
    -payment_type:required
    -payment_term:required
    -partner_text:required
    -roommates_text:required
    -cell_phone:required
    -ha_line1:required
    -ha_city:required
    -ha_state:required
    -ha_postal_code:required
    -ha_country_code:required
} {
    @author Neophytos Demetriou (neophytos@azet.sk)
    @creation-date 2014-11-11
    @last-modified 2014-11-11
} {

    set sql "
        select course,accommodation,food_choice,bus_option,event_participant_status_id
        from flyhh_event_participants
        where participant_id=:participant_id
    "

    db_1row participant_info $sql -column_array old

    set from_status_id $old(event_participant_status_id)
    set to_status_id $old(event_participant_status_id)

    set delta_items [list \
        [list $old(course)        $from_status_id ""] \
        [list $old(accommodation) $from_status_id ""] \
        [list $old(food_choice)   $from_status_id ""] \
        [list $old(bus_option)    $from_status_id ""] \
        [list $course        "" $to_status_id] \
        [list $accommodation "" $to_status_id] \
        [list $food_choice   "" $to_status_id] \
        [list $bus_option    "" $to_status_id]]

    set creation_ip [ad_conn peeraddr]

    ::flyhh::match_name_email $partner_text partner_name partner_email

    db_transaction {

        db_exec_plsql insert_participant "select flyhh_event_participant__update(

            :participant_id,
            :email,
            :first_names,
            :last_name,
            :creation_ip,
            :project_id,
            :lead_p,
            :partner_text,
            :partner_name,
            :partner_email,
            :accepted_terms_p,
            :course,
            :accommodation,
            :food_choice,
            :bus_option,
            :level,
            :payment_type,
            :payment_term

        )"

        ::flyhh::set_user_contact_info \
            -email $email \
            -cell_phone $cell_phone \
            -ha_line1 $ha_line1 \
            -ha_city  $ha_city \
            -ha_state $ha_state \
            -ha_postal_code $ha_postal_code \
            -ha_country_code $ha_country_code

        set roommates_list [lsearch -all -inline -not [split $roommates_text ",|\t\n\r"] {}]

        foreach roommate_text $roommates_list {

            ::flyhh::match_name_email $roommate_text roommate_name roommate_email

            # TODO: updating roommates is not done yet
            continue
            db_exec_plsql insert_roommate "select flyhh_event_roommate__new(
                :participant_id,
                :project_id,
                :roommate_email,
                :roommate_name
            )"

        }

        db_exec_plsql status_automaton "select flyhh_event_participant__status_automaton(:participant_id)"

        ::flyhh::update_event_stats -project_id $project_id -delta_items $delta_items

    }

}


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
    set invoice_template [parameter::get -parameter invoice_template -default "RechnungCognovis.en.odt"]

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

    db_transaction {
        set invoice_nr [im_next_invoice_nr -cost_type_id [im_cost_type_invoice]]
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
                vat_type_id = 42021 
            where cost_id = :invoice_id
         "

        if { $invoice_type_id ne {3725} && $delta_items eq {} } {

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

            foreach varname {course accommodation food_choice bus_option} {
                set material_id [set $varname]

                if { $material_id eq {} } { continue }

                lappend delta_items [list 1.0 1.0 $material_id]
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

ad_proc ::flyhh::update_event_stats {
    -project_id:required
    -delta_items:required
} {

    @param delta_items is a list of {material_id from_status_id to_status_id} triplets

    @author Neophytos Demetriou (neophytos@azet.sk)
    @creation-date 2014-11-13
    @last-modified 2014-11-13
} {

    set sql "
        select category_id 
        from im_categories 
        where category_type='Flyhh - Event Registration Status' 
        and category in ('Confirmed','Pending Payment','Partially Paid')
    "

    set confirmed_list [db_list_of_lists confirmed_list $sql]

    set sql "
        select category_id 
        from im_categories 
        where category_type='Flyhh - Event Registration Status' 
        and category='Registered'
    "

    set registered_list [db_list_of_lists registered_list $sql]


    set new_delta_items [list]

    foreach item $delta_items {

        foreach {material_id from_status_id to_status_id} $item break

        if { $material_id eq {} } {continue}

        if { -1 != [lsearch -exact $confirmed_list $from_status_id] } {
            lappend new_delta_items [list $material_id -1 0]
        }

        if { -1 != [lsearch -exact $registered_list $from_status_id] } {
            lappend new_delta_items [list $material_id 0 -1]
        }

        if { -1 != [lsearch -exact $confirmed_list $to_status_id] } {
            lappend new_delta_items [list $material_id 1 0]
        }

        if { -1 != [lsearch -exact $registered_list $to_status_id] } {
            lappend new_delta_items [list $material_id 0 1]
        }

    }

    # there are only four materials in the participant record
    # namely course, accommodation, food_choice, bus_option
    # we will update the stats for at most eight materials here
    # we could speed it up by creating a separate table for the
    # stats of each event or by adding an hstore column in the 
    # events table itself
    foreach item $new_delta_items {

        foreach {material_id delta_confirmed delta_registered} $item break

        # update capacity stats
        set sql "
            update flyhh_event_materials set
                num_confirmed  = num_confirmed + :delta_confirmed,
                num_registered = num_registered + :delta_registered,
                free_capacity  = capacity - (num_registered + :delta_registered),
                free_confirmed_capacity = capacity - (num_confirmed + num_registered + :delta_confirmed + :delta_registered)
            where material_id = :material_id
        "

        db_dml update_stats $sql

    }

}


ad_proc ::flyhh::set_participant_status { 
    {-participant_id:required ""}
    {-to_status:required ""}
    {-from_status ""}
} {
    @author Neophytos Demetriou (neophytos@azet.sk)
    @creation-date 2014-11-04
    @last-modified 2014-11-12
} {

    set sql "
        select project_id, course, accommodation, food_choice, bus_option, event_participant_status_id
        from flyhh_event_participants where participant_id=:participant_id
    "
    db_1row participant_info $sql

    set to_status_id [::flyhh::status_id_from_name $to_status]

    if { $from_status ne {} } {

        set from_status_id [::flyhh::status_id_from_name $from_status]

        set sql "
            update flyhh_event_participants 
            set event_participant_status_id=:to_status_id 
            where participant_id=:participant_id 
            and event_participant_status_id=:from_status_id
        "

        set statement_name "update_event_participant_status_if"

    } else {

        set from_status_id $event_participant_status_id

        set sql "
            update flyhh_event_participants 
            set event_participant_status_id=:to_status_id 
            where participant_id=:participant_id
        "

        set statement_name "update_event_participant_status"

    }


    if { $event_participant_status_id ne $from_status_id } {
        error "set_participant_status: event_participant_status_id=$event_participant_status_id from_status_id=$from_status_id"
    }

    set delta_items [list \
        [list $course        $from_status_id $to_status_id] \
        [list $accommodation $from_status_id $to_status_id] \
        [list $food_choice   $from_status_id $to_status_id] \
        [list $bus_option    $from_status_id $to_status_id]]

    db_transaction {

        if { $to_status eq {Cancelled} } {

            ::flyhh::set_to_cancelled_helper -participant_id $participant_id

        }

        # update event participant status
        db_dml $statement_name $sql

        ::flyhh::update_event_stats -project_id $project_id -delta_items $delta_items

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

ad_proc ::flyhh::check_event_exists {
    -project_id
} {
    @author Neophytos Demetriou (neophytos@azet.sk)
    @creation-date 2014-11-11
    @last-modified 2014-11-11
} {
    set sql "select 1 from flyhh_events where project_id=:project_id limit 1"
    set is_event_proj_p [db_string check_event_project $sql -default 0]
    if { !$is_event_proj_p } {
        ad_complain "no event found for the given project_id (=$project_id)"
    }
}

ad_proc ::flyhh::check_confirmed_free_capacity {
    -project_id:required
    -participant_id_list:required
} {
    @author Neophytos Demetriou (neophytos@azet.sk)
    @creation-date 2014-11-14
    @last-modified 2014-11-14
} {

    set sql_list [template::util::tcl_to_sql_list $participant_id_list]

    set sql "
        select course,accommodation,food_choice,bus_option
        from flyhh_event_participants
        where participant_id in (${sql_list})
    "
    array set delta [list]
    db_foreach participant_registration $sql {

        foreach var [list delta($course) delta($accommodation) delta($food_choice) delta($bus_option)] {
            if { ![info exists $var] } { set $var 0 }
        }

        incr delta($course)
        incr delta($accommodation)
        incr delta($food_choice)
        incr delta($bus_option)

    }

    if { [info exists delta("")] } {
        unset delta("")
    }

    foreach {material_id delta_count} [array get delta] {

        set sql "
            select free_confirmed_capacity
            from flyhh_event_materials em inner join flyhh_events evt on (evt.event_id=em.event_id)
            where project_id=:project_id
            and material_id=:material_id 
            and free_confirmed_capacity < :delta_count
        "

        set exceeds_capacity_num [db_string exceeds_capacity_num $sql -default 0]

        if { $exceeds_capacity_num } {
            set sql "
                select 
                    material_name,
                    material_type
                from im_materials m inner join im_material_types mt on (mt.material_type_id=m.material_type_id)
                where material_id=:material_id
            "
            db_1row material_info $sql
            ad_complain "request for confirmation of $delta_count \"${material_name}\" (${material_type}) exceeds free confirmed capacity (=${exceeds_capacity_num})"
        }

    }

}

ad_proc ::flyhh::send_invoice_mail {
    -invoice_id
    -from_addr
    {-recipient_id ""}
    {-cc_addr ""}
    {-project_id ""}
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

    # Get the type information so we can get the strings
    set invoice_type_id [db_string type "select cost_type_id from im_costs where cost_id = :invoice_id"]
    
    set recipient_locale [lang::user::locale -user_id $recipient_id]
    set subject [lang::util::localize "#intranet-invoices.invoice_email_subject_${invoice_type_id}#" $recipient_locale]
    set body [lang::util::localize "#intranet-invoices.invoice_email_body_${invoice_type_id}#" $recipient_locale]

    acs_mail_lite::send -send_immediately -to_addr $to_addr -from_addr $from_addr -cc_addr $cc_addr -subject $subject -body $body -file_ids $invoice_revision_id -use_sender -object_id $project_id

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
                
        } elseif { $cost_status_id eq $cost_status_partially_paid || $paid_amount > 0 } {

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
        -object_id $project_id


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

    # When you submit the registration and the dance partner did not register, send the dance partner an E-Mail (text
    # does not matter now) with a link to the registration for the event and the partner who asked them to join, so this
    # is already pre-filled?

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

ad_proc ::flyhh::import_template_file {
    template_file
} {
    @author Neophytos Demetriou (neophytos@azet.sk)
    @creation-date 2014-11-11
    @last-modified 2014-11-11
} {

    set template_name [file tail $template_file]

    set sql "select count(1) from im_categories where category = :template_name and category_type = 'Intranet Cost Template'"
    set cat_exists_p [db_string ex $sql]
    if {!$cat_exists_p} {

        set template_path [im_filestorage_template_path]
        ns_cp $template_file "$template_path/$template_name"

        set cat_id [db_nextval "im_categories_seq"]
        set cat_id_exists_p [db_string cat_ex "select count(1) from im_categories where category_id = :cat_id"]
        while {$cat_id_exists_p} {
            set cat_id [db_nextval "im_categories_seq"]
            set cat_id_exists_p [db_string cat_ex "select count(1) from im_categories where category_id = :cat_id"]
        }

        db_dml new_cat "
            insert into im_categories (
                    category_id,
                    category,
                    category_type,
                    enabled_p
            ) values (
                    nextval('im_categories_seq'),
                    :template_name,
                    'Intranet Cost Template',
                    't'
            )
        "
    }

}

ad_proc ::flyhh::after_confirmation_edit_p {
    event_participant_status_id
} {
    @author Neophytos Demetriou (neophytos@azet.sk)
    @creation-date 2014-11-12
    @last-modified 2014-11-12
} {

    # If the status of the event registration is no longer pending, 
    # do not allow the editing of any fields but the name,
    # address, dance partner and room mates.
    #
    # Pending Payment (=82502), Partially Paid (=82503), Registered (=82504), Refused (=82505), Cancelled (=82506)

    set sql "
        select category_id 
        from im_categories 
        where category_type='Flyhh - Event Registration Status' 
        and category in ('Pending Payment','Partially Paid', 'Registered', 'Refused', 'Cancelled')
    "
    set restrict_edit_list [db_list_of_lists restrict_edit_list $sql]

    return [expr { -1 != [lsearch -exact -integer $restrict_edit_list $event_participant_status_id] }]

}

ad_proc ::flyhh::record_after_confirmation_edit {
    -participant_id:required
    oldVar
    newVar
} {
    @author Neophytos Demetriou (neophytos@azet.sk)
    @creation-date 2014-11-12
    @last-modified 2014-11-12
} {

    upvar $oldVar old
    upvar $newVar new

    ns_log notice "record_after_confirmation_edit: old=[array get old] new=[array get new]"

    set provider_company_id [parameter::get -parameter provider_company_id -default "8720"]

    set sql "
        select 
            project_id,
            person_id as company_contact_id,
            payment_type as payment_method_id,
            payment_term as payment_term_id,
            company_id,
            quote_id,
            invoice_id
        from flyhh_event_participants
        where participant_id=:participant_id
    "

    db_1row participant_info $sql

    # each delta item consists of three numbers: 
    # item_units, percent of price, and material_id
    # e.g. -1.0 0.7 34832
    set delta_items [list]

    set before_refund_reduction_date_p true  ;# TODO

    set before_refund_cutoff_date_p true     ;# TODO

    foreach element {course accommodation food_choice bus_option} {

        if { $old($element) ne $new($element) } {

            set old_material_id $old($element)
            set new_material_id $new($element)
            set sql "
                select 
                    (select price from im_timesheet_prices where company_id=:provider_company_id and material_id=:old_material_id) as old_price,
                    (select price from im_timesheet_prices where company_id=:provider_company_id and material_id=:new_material_id) as new_price
            "
            db_1row old_and_new_price $sql

            ns_log notice "record_after_confirmation_edit: old_price=$old_price new_price=$new_price"

            # in case the change is for the classes material
            if { $element eq {course} } {

                # If the price of the new material is lower then the old material, just change the registration
                # information, do not change the invoice. We do not offer refunds on classes.

                if { $new_price <= $old_price } {}

                # If the price of the new material is higher then the old material, create a correction invoice with a credit line for
                # the old material and a debit line for the new material. The resulting invoice should therefore show
                # the difference between the two materials.

                if { $new_price > $old_price } {
                    lappend delta_items [list -1.0 1.0 $old(course)]
                    lappend delta_items [list 1.0 1.0 $new(course)]
                }

            } else {

                # In case the change is for anything else and the prices differ:

                # If the change date is after the refund_cutoff_date do nothing with regards to the invoice.
                if { !$before_refund_cutoff_date_p } {continue}

                # If the change date is before the refund_reduction_date or the new price is HIGHER then the old price, create a new
                # invoice with two line items, one is a FULL credit for the old material and one is new debit line
                # for the new material. 

                if { $before_refund_reduction_date_p || $new_price > $old_price } {
                    lappend delta_items [list -1.0 1.0 $old($element)]
                    lappend delta_items [list 1.0 1.0 $new($element)]
                }

                # If the change date is after the refund_reduction_date but before the refund_cutoff_date and the
                # new price is LOWER then the old price, create a new invoice with two line items, one is a 70%
                # credit for the old material and one is a new debit line for the new material. If there is no new
                # material (e.g. because the customer does not want the bus anymore, you only have a credit line
                # with 70%). 

                if { !$before_refund_reduction_date_p && $before_refund_cutoff_date_p && $new_price < $old_price } {
                    lappend delta_items [list -1.0 0.7 $old($element)]
                    lappend delta_items [list 1.0 1.0 $new($element)]
                }

            }

        }

    }

    set invoice_type_id 3725  ;# Intranet Cost Type (3725 = Customer Invoice Correction)

    set new_invoice_id \
        [::flyhh::create_invoice \
            -company_id $company_id \
            -company_contact_id $company_contact_id \
            -participant_id $participant_id \
            -project_id $project_id \
            -payment_method_id $payment_method_id \
            -payment_term_id $payment_term_id \
            -invoice_type_id $invoice_type_id \
            -delta_items $delta_items]

    if { $invoice_id ne {} } {
        # add relationship between original invoice and correction invoice 
        set rel_id [db_exec_plsql create_rel "
            select acs_rel__new (
                 null,                      -- rel_id
                 'im_invoice_invoice_rel',  -- rel_type
                 :invoice_id,               -- object_id_one
                 :new_invoice_id,           -- object_id_two
                 null,                      -- context_id
                 null,                      -- creation_user
                 null                       -- creation_ip
            )"]
    }

}

ad_proc -private ::flyhh::set_to_cancelled_helper {
    -participant_id:required
} {
    @author Neophytos Demetriou (neophytos@azet.sk)
    @creation-date 2014-11-12
    @last-modified 2014-11-12
} {


    set sql "
        select
            course,
            accommodation,
            food_choice,
            bus_option,
            event_participant_status_id
        from flyhh_event_participants
        where participant_id=:participant_id
    "

    db_1row participant_info $sql -column_array old

    if { [::flyhh::after_confirmation_edit_p $old(event_participant_status_id)] } {

        array set new [list course "" accommodation "" food_choice "" bus_option ""]

        ::flyhh::record_after_confirmation_edit -participant_id $participant_id old new

    }

}

# ---------------------------------------------------------------
# Callbacks
# 
# Generically create callbacks for all "package" object types
# ---------------------------------------------------------------

set object_types {
    flyhh_event
    flyhh_event_participant
}

foreach object_type $object_types {
    
    ad_proc -public -callback ${object_type}_before_create {
	{-object_id:required}
	{-status_id ""}
	{-type_id ""}
    } {
	This callback allows you to execute action before and after every
	important change of object. Examples:
	- Copy preset values into the object
	- Integrate with external applications via Web services etc.
	
	@param object_id ID of the $object_type 
	@param status_id Optional status_id category. 
		   This value is optional. You need to retrieve the status
		   from the DB if the value is empty (which should rarely be the case)
		   This field allows for quick filtering if the callback 
		   implementation is to be executed only on certain object types.
	@param type_id Optional type_id of category.
		   This value is optional. You need to retrieve the status
		   from the DB if the value is empty (which should rarely be the case)
		   This field allows for quick filtering if the callback 
		   implementation is to be executed only on certain object states.
    } -
    
    ad_proc -public -callback ${object_type}_after_create {
	{-object_id:required}
	{-status_id ""}
	{-type_id ""}
    } {
	This callback allows you to execute action before and after every
	important change of object. Examples:
	- Copy preset values into the object
	- Integrate with external applications via Web services etc.
	
	@param object_id ID of the $object_type 
	@param status_id Optional status_id category. 
		   This value is optional. You need to retrieve the status
		   from the DB if the value is empty (which should rarely be the case)
		   This field allows for quick filtering if the callback 
		   implementation is to be executed only on certain object types.
	@param type_id Optional type_id of category.
		   This value is optional. You need to retrieve the status
		   from the DB if the value is empty (which should rarely be the case)
		   This field allows for quick filtering if the callback 
		   implementation is to be executed only on certain object states.
    } -


    
    ad_proc -public -callback ${object_type}_before_update {
	{-object_id:required}
	{-status_id ""}
	{-type_id ""}
    } {
	This callback allows you to execute action before and after every
	important change of object. Examples:
	- Copy preset values into the object
	- Integrate with external applications via Web services etc.
	
	@param object_id ID of the $object_type 
	@param status_id Optional status_id category. 
		   This value is optional. You need to retrieve the status
		   from the DB if the value is empty (which should rarely be the case)
		   This field allows for quick filtering if the callback 
		   implementation is to be executed only on certain object types.
	@param type_id Optional type_id of category.
		   This value is optional. You need to retrieve the status
		   from the DB if the value is empty (which should rarely be the case)
		   This field allows for quick filtering if the callback 
		   implementation is to be executed only on certain object states.
    } -
    
    ad_proc -public -callback ${object_type}_after_update {
	{-object_id:required}
	{-status_id ""}
	{-type_id ""}
    } {
	This callback allows you to execute action before and after every
	important change of object. Examples:
	- Copy preset values into the object
	- Integrate with external applications via Web services etc.
	
	@param object_id ID of the $object_type 
	@param status_id Optional status_id category. 
		   This value is optional. You need to retrieve the status
		   from the DB if the value is empty (which should rarely be the case)
		   This field allows for quick filtering if the callback 
		   implementation is to be executed only on certain object types.
	@param type_id Optional type_id of category.
		   This value is optional. You need to retrieve the status
		   from the DB if the value is empty (which should rarely be the case)
		   This field allows for quick filtering if the callback 
		   implementation is to be executed only on certain object states.
    } -


    
    ad_proc -public -callback ${object_type}_before_delete {
	{-object_id:required}
	{-status_id ""}
	{-type_id ""}
    } {
	This callback allows you to execute action before and after every
	important change of object. Examples:
	- Copy preset values into the object
	- Integrate with external applications via Web services etc.
	
	@param object_id ID of the $object_type 
	@param status_id Optional status_id category. 
		   This value is optional. You need to retrieve the status
		   from the DB if the value is empty (which should rarely be the case)
		   This field allows for quick filtering if the callback 
		   implementation is to be executed only on certain object types.
	@param type_id Optional type_id of category.
		   This value is optional. You need to retrieve the status
		   from the DB if the value is empty (which should rarely be the case)
		   This field allows for quick filtering if the callback 
		   implementation is to be executed only on certain object states.
    } -
    
    ad_proc -public -callback ${object_type}_after_delete {
	{-object_id:required}
	{-status_id ""}
	{-type_id ""}
    } {
	This callback allows you to execute action before and after every
	important change of object. Examples:
	- Copy preset values into the object
	- Integrate with external applications via Web services etc.
	
	@param object_id ID of the $object_type 
	@param status_id Optional status_id category. 
		   This value is optional. You need to retrieve the status
		   from the DB if the value is empty (which should rarely be the case)
		   This field allows for quick filtering if the callback 
		   implementation is to be executed only on certain object types.
	@param type_id Optional type_id of category.
		   This value is optional. You need to retrieve the status
		   from the DB if the value is empty (which should rarely be the case)
		   This field allows for quick filtering if the callback 
		   implementation is to be executed only on certain object states.
    } -

    ad_proc -public -callback ${object_type}_view {
	{-object_id:required}
	{-status_id ""}
	{-type_id ""}
    } {
	This callback tracks acess to the object's main page.
	
	@param object_id ID of the $object_type 
	@param status_id Optional status_id category. 
		   This value is optional. You need to retrieve the status
		   from the DB if the value is empty (which should rarely be the case)
		   This field allows for quick filtering if the callback 
		   implementation is to be executed only on certain object types.
	@param type_id Optional type_id of category.
		   This value is optional. You need to retrieve the status
		   from the DB if the value is empty (which should rarely be the case)
		   This field allows for quick filtering if the callback 
		   implementation is to be executed only on certain object states.
    } -

    ad_proc -public -callback ${object_type}_form_fill {
        -form_id:required
        -object_id:required
        { -object_type "" }
        { -type_id ""}
        { -page_url "default" }
        { -advanced_filter_p 0 }
        { -include_also_hard_coded_p 0 }
    } {
	This callback tracks acess to the object's main page.
	
	@param object_id ID of the $object_type 
	@param status_id Optional status_id category. 
		   This value is optional. You need to retrieve the status
		   from the DB if the value is empty (which should rarely be the case)
		   This field allows for quick filtering if the callback 
		   implementation is to be executed only on certain object types.
	@param type_id Optional type_id of category.
		   This value is optional. You need to retrieve the status
		   from the DB if the value is empty (which should rarely be the case)
		   This field allows for quick filtering if the callback 
		   implementation is to be executed only on certain object states.
    } -

    ad_proc -public -callback ${object_type}_on_submit {
        -form_id:required
        -object_id:required
    } {
        This callback allows for additional validations and it should be called in the on_submit block of a form
        
        Usage: 
            form set_error $form_id $error_field $error_message
            break

        @param object_id ID of the $object_type
        @param form_id ID of the form which is being submitted
    } -


}

ad_proc -public flyhh_event_participant_permissions {user_id participant_id view_var read_var write_var admin_var} {
    Fill the "by-reference" variables read, write and admin
    with the permissions of $user_id on $participant_id.
    
    Currently defaults to grant all permissions. Need to fine grain this later
} {
    upvar $view_var view
    upvar $read_var read
    upvar $write_var write
    upvar $admin_var admin

    set current_user_id $user_id
    set view 1
    set read 1
    set write 1
    set admin 1
}

ad_proc -public im_note_type_skill {} { return 11515 }
ad_proc -public im_note_type_accommodation {} { return 11516 }

ad_proc -public flyhh_material_options {
    -project_id:required
    -material_type:required
    { -company_id "" }
    { -locale ""}
    -mandatory:boolean
} {
    Returns a list of viable options for display in the registration form
} {
    set material_options [list]
    if {!$mandatory_p} {
        lappend material_options [list "" ""]
    }
    
    if {$company_id eq ""} {
        set company_id [im_company_internal]
    }
    if {$locale eq ""} {
        set locale [lang::user::locale]
    }
    
    db_foreach materials "SELECT m.material_id,material_name,p.price,p.currency FROM im_timesheet_prices p,im_materials m, flyhh_event_materials f,flyhh_events e WHERE m.material_type_id=(SELECT material_type_id FROM im_material_types WHERE material_type=:material_type) and f.material_id = m.material_id and f.event_id = e.event_id and e.project_id = :project_id and f.capacity >0 and p.material_id = m.material_id and p.company_id = :company_id" {
        set price [lc_numeric [im_numeric_add_trailing_zeros [expr $price+0] 2] "" $locale]
        set material_display "$material_name ($currency $price)"
        lappend material_options [list $material_display $material_id]
    }
    
    return $material_options
    
}