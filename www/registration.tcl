ad_page_contract {
    
    flying hamburger registration page
    
    @author Neophytos Demetriou (neophytos@azet.sk)
    @creation-date 2014-10-15
    @last-modified 2014-10-30
    @cvs-id $Id$
} {
    participant_id:integer,optional,notnull
    project_id:integer,notnull
    token:optional,notnull
} -properties {
} -validate {

    event_exists_ck -requires {project_id:integer} {

        set sql "select 1 from flyhh_events where project_id=:project_id limit 1"
        set is_event_proj_p [db_string check_event_project $sql -default 0]
        if { !$is_event_proj_p } {
            ad_complain "no event found for the given project_id (=$project_id)"
        }

    }

} -errors {
}

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
set context [ad_context_bar $page_title]

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

        {email:text
            {label "Email"}}

        {first_names:text
            {label "First Name"}
        }
        
        {last_name:text
            {label "Last Name"}
        }

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
        {label "Lead/Follow"}
        {options {{Lead t} {Follow f}}}}

    {partner_text:text
        {label "Partner"}
        {help_text "email address, name, or both"}
        {html {style "width:300px;"}}}

    {roommates:text(textarea)
        {label "Roommates"}
        {html "rows 4 cols 30"}
        {help_text "comma-separated list of email addresses, names, or both"}}

    {accepted_terms_p:boolean(checkbox)
        {label "Terms & Conditions"}
        {options {{{<a href="https://www.startpage.com/">some text</a>} t}}}}

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
        set sql "select first_names, last_name, email from parties pa inner join persons p on (p.person_id=pa.party_id) where person_id=:user_id"
        db_1row user_info $sql


    }


} -edit_request {

    set sql "select *
             from flyhh_event_participants ep 
             inner join parties pa on (pa.party_id=ep.person_id) 
             inner join persons p on (p.person_id=ep.person_id) 
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
    set restrict_edit_list [parameter::get -package_id $package_id -parameter "restrict_edit_list"]
    if { -1 != [lsearch -exact -integer $restrict_edit_list $event_participant_status_id] } {
        foreach element {
            email accommodation food_choice bus_option level 
            payment_type payment_term lead_p
            accepted_terms_p
        } {
            template::element::set_properties $form_id $element mode display
        }
    }

} -validate {

    {partner_text

        {[::flyhh::match_name_email $partner_text partner_name partner_email]}

        "partner text must be an email address, full name, or both"}

} -on_submit {
    
    if { [ad_form_new_p -key participant_id] } {
     
        set creation_ip [ad_conn peeraddr]

        ::flyhh::match_name_email $partner_text partner_name partner_email

        db_transaction {

            db_exec_plsql insert_participant "select flyhh_event_participant__new(

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

                :accommodation,
                :food_choice,
                :bus_option,
                :level,
                
                :payment_type,
                :payment_term

            )"

            set roommates_list [lsearch -all -inline -not [split $roommates ",|\t\n\r"] {}]

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

    } else {

        set creation_ip [ad_conn peeraddr]

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

                :accommodation,
                :food_choice,
                :bus_option,
                :level,
                
                :payment_type,
                :payment_term

            )"

            set roommates_list [lsearch -all -inline -not [split $roommates ",|\t\n\r"] {}]

            foreach roommate_text $roommates_list {

                ::flyhh::match_name_email $roommate_text roommate_name roommate_email

                # TODO: updating roommates is not done yet

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

} -after_submit {
    ad_returnredirect [export_vars -base registration {project_id participant_id}]
}



