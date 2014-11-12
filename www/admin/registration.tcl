ad_page_contract {
    
    flying hamburger registration page
    
    @author Neophytos Demetriou (neophytos@azet.sk)
    @creation-date 2014-10-15
    @last-modified 2014-11-11
    @cvs-id $Id$
} {
    participant_id:integer,optional,notnull
    project_id:integer,notnull
    token:optional,notnull
    {inviter_text:trim,notnull ""}
} -properties {
} -validate {

    check_event_exists -requires {project_id:integer} {

        ::flyhh::check_event_exists -project_id $project_id

    }

} -errors {
}

# ad_maybe_redirect_for_registration

set package_id [ad_conn package_id]
set user_id [ad_conn user_id]
set admin_p [permission::permission_p -object_id $package_id -party_id $user_id -privilege admin]

# TODO: token parameter is not meant to be optional
# it is going to be a signed key that helps us extract
# the project_id and it prevents sequential access
# to event registration pages. For debugging purposes,
# we use an arbitrary project_id that we create for
# company 8720, i.e. Flying Hamburger Events UG.
#
#set sql "select project_id from im_projects where project_type_id=102 and company_id=8720 limit 1"
#set project_id [db_string some_project_id $sql]

set page_title "Registration Form"
set context_bar [ad_context_bar $page_title]

set form_id "registration_form"
set action_url ""
set object_type "flyhh_event_participant" ;# used for appending dynfields to form

if { [exists_and_not_null participant_id] } {
    set mode display
} else {
    set mode edit
}

ad_form \
    -name $form_id \
    -action $action_url \
    -mode $mode \
    -export project_id \
    -form {

        participant_id:key(acs_object_id_seq)

        {-section basic_info
            {legendtext {[::flyhh::mc Basic_Info_Section "Basic Info"]}}}

        {email:text
            {label {[::flyhh::mc Participant_Email "Email"]}}}

        {first_names:text
            {label {[::flyhh::mc Participant_First_Name "First Name"]}}}
        
        {last_name:text
            {label {[::flyhh::mc Participant_Last_Name "Last Name"]}}}

        {-section event_preferences
            {legendtext {[::flyhh::mc Event_Registration_Section "Event Registration"]}}}
        
    }

im_dynfield::append_attributes_to_form \
    -object_type $object_type \
    -form_id $form_id \
    -object_id 0 \
    -advanced_filter_p 0

# Set the form values from the HTTP form variable frame
im_dynfield::set_form_values_from_http -form_id $form_id
im_dynfield::set_local_form_vars_from_http -form_id $form_id

ad_form -extend -name $form_id -form {

    {lead_p:text(select)
        {label {[::flyhh::mc Lead_or_Follow "Lead/Follow"]}}
        {options {{Lead t} {Follow f}}}}

    {partner_text:text
        {label {[::flyhh::mc Partner "Partner"]}}
        {value "${inviter_text}"}
        {help_text "email address, name, or both<br>(email is preferred as we can notify your partner to register)"}
        {html {style "width:300px;"}}}

    {roommates_text:text(textarea),optional
        {label {[::flyhh::mc Roommates "Roommates"]}}
        {html "rows 4 cols 30"}
        {help_text "comma-separated list of email addresses, names, or both"}}

    {-section contact_details
        {legendtext {[::flyhh::mc Contact_Details_Section "Contact Details"]}}}
        
    {cell_phone:text,optional
        {label {[::flyhh::mc Phone "Phone"]}}}

    {ha_line1:text,optional
        {label {[::flyhh::mc Address_Line_1 "Address Line 1"]}}
        {html {size 30}}}

    {ha_line2:text,optional
        {label {[::flyhh::mc Address_Line_2 "Address Line 2"]}}
        {html {size 30}}}

    {ha_city:text,optional
        {label {[::flyhh::mc City "City"]}}
        {html {size 15}}}

    {ha_state:text,optional
        {label {[::flyhh::mc State "State"]}}
        {html {size 2}}}

    {ha_postal_code:text,optional
        {label {[::flyhh::mc Postal_code "Postal Code"]}}
        {html {size 5}}}

    {ha_country_code:text(generic_sql),optional
        {label {[::flyhh::mc Country "Country"]}}
        {html {}}
        {custom {sql {select iso,default_name from countries}}}}

    # Unset the section. subsequent elements will not be in any section.
    {-section ""}

    {accepted_terms_p:boolean(checkbox)
        {label {[::flyhh::mc Terms_and_Conditions "Terms & Conditions"]}}
        {options {{{<a href="https://www.startpage.com/">I have read and accept the terms and conditions for this event</a>} t}}}}

} -new_request {

    if { [set user_id [ad_conn user_id]] } {

        # If a registered user who is already registered for this event wants to register anew, redirect to edit the registration page
        set sql "select participant_id from flyhh_event_participants where person_id=:user_id and project_id=:project_id"
        set exists_participant_id [db_string registration_exists $sql -default ""]
        if { $exists_participant_id ne {} } {
            ad_returnredirect [export_vars -base registration { project_id { participant_id $exists_participant_id } }]
            return
        }

        # If a registered user who already has information in the system registers for a new event, pre fill the known information.
        set sql "
            select first_names, last_name, email 
            from parties pa 
            inner join persons p on (p.person_id=pa.party_id) 
            left outer join users_contact uc on (uc.user_id=pa.party_id)
            where person_id=:user_id"
        db_1row user_info $sql


    }


} -edit_request {

    set sql "select *
             from flyhh_event_participants ep 
             inner join parties pa on (pa.party_id=ep.person_id) 
             inner join persons p on (p.person_id=ep.person_id) 
             inner join users_contact uc on (uc.user_id=ep.person_id)
             where participant_id=:participant_id"

    db_1row event_participant $sql

    set sql "select * from flyhh_event_roommates where participant_id=:participant_id"
    set roommates ""
    db_foreach roommate $sql {
        append roommates $roommate_email "\n"
    }

    set form_elements [template::form::get_elements $form_id]
    foreach element $form_elements {
        if { [info exists $element] } {
            set value [set $element]
            template::element::set_value $form_id $element $value
        }
    }

    set package_id [ad_conn package_id]

    if { [::flyhh::after_confirmation_edit_p $event_participant_status_id] } {

        set material_type_fields {course accommodation food_choice bus_option} 
        
        foreach element {
            email course accommodation food_choice bus_option level 
            payment_type payment_term lead_p
        } {

            if { $admin_p && -1 != [lsearch -exact $material_type_fields $element] } {

                set help_text "<font color=red><i>edit after confirmation, alters invoice</i></font>"
                template::element::set_properties $form_id $element help_text $help_text

            } elseif { $admin_p && -1 != [lsearch -exact {level payment_type payment_term lead_p} $element] } {
                # admins can further edit these fields
            } else {

                template::element::set_properties $form_id $element mode display

            }

        }

    }

} -validate {

    {partner_text
        {[::flyhh::match_name_email $partner_text partner_name partner_email]}
        {[::flyhh::mc partner_text_validation_error "partner text must be an email address, full name, or both"]}}

} -on_submit {
    
    if { [ad_form_new_p -key participant_id] } {
     
        ::flyhh::create_participant \
            -participant_id $participant_id \
            -project_id $project_id \
            -email $email \
            -first_names $first_names \
            -last_name $last_name \
            -accepted_terms_p $accepted_terms_p \
            -course $course \
            -accommodation $accommodation \
            -food_choice $food_choice \
            -bus_option $bus_option \
            -level $level \
            -lead_p $lead_p \
            -payment_type $payment_type \
            -payment_term $payment_term \
            -partner_text $partner_text \
            -roommates_text $roommates_text \
            -cell_phone $cell_phone \
            -ha_line1 $ha_line1 \
            -ha_line2 $ha_line2 \
            -ha_city $ha_city \
            -ha_state $ha_state \
            -ha_postal_code $ha_postal_code \
            -ha_country_code $ha_country_code

    } else {
        
        set sql "select course, accommodation, food_choice, bus_option, event_participant_status_id
                 from flyhh_event_participants ep 
                 inner join parties pa on (pa.party_id=ep.person_id) 
                 inner join persons p on (p.person_id=ep.person_id) 
                 inner join users_contact uc on (uc.user_id=ep.person_id)
                 where participant_id=:participant_id"

        db_1row event_participant $sql -column_array old

        db_transaction {

            if { [::flyhh::after_confirmation_edit_p $old(event_participant_status_id)] } {

                array set new [list \
                    course $course \
                    accommodation $accommodation \
                    food_choice $food_choice \
                    bus_option $bus_option]

                ::flyhh::record_after_confirmation_edit -participant_id $participant_id old new

            }

            ::flyhh::update_participant \
                -participant_id $participant_id \
                -project_id $project_id \
                -email $email \
                -first_names $first_names \
                -last_name $last_name \
                -accepted_terms_p $accepted_terms_p \
                -course $course \
                -accommodation $accommodation \
                -food_choice $food_choice \
                -bus_option $bus_option \
                -level $level \
                -lead_p $lead_p \
                -payment_type $payment_type \
                -payment_term $payment_term \
                -partner_text $partner_text \
                -roommates_text $roommates_text \
                -cell_phone $cell_phone \
                -ha_line1 $ha_line1 \
                -ha_line2 $ha_line2 \
                -ha_city $ha_city \
                -ha_state $ha_state \
                -ha_postal_code $ha_postal_code \
                -ha_country_code $ha_country_code

        }        
    }

} -after_submit {
    ad_returnredirect [export_vars -base registration {project_id participant_id}]
}



