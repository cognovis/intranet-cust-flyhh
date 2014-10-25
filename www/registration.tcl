ad_page_contract {
    
    flying hamburger registration page
    
    @author Neophytos Demetriou (neophytos@azet.sk)
    @creation-date 2014-10-15
    @last-modified 2014-10-23
    @cvs-id $Id$
} {
    participant_id:integer,optional,notnull
    token:optional,notnull
} -properties {
} -validate {
} -errors {
}

# TODO: token parameter is not meant to be optional
# it is going to be a signed key that helps us extract
# the project_id and it prevents sequential access
# to event registration pages. For debugging purposes,
# we use an arbitrary project_id that we create for
# company 8720, i.e. Flying Hamburger Events UG.
#
set sql "select project_id from im_projects where project_type_id=102 and company_id=8720 limit 1"
set project_id [db_string some_project_id $sql]

set page_title "Registration Form"
set context [ad_context_bar "Registration Form"]

set form_id "registration_form"
set action_url ""
set object_type "im_event_participant" ;# used for appending dynfields to form

if { [exists_and_not_null participant_id] } {
    set mode display
} else {
    set mode edit
}

ad_form \
    -name $form_id \
    -action $action_url \
    -mode $mode \
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




# TODO: figure out how to filter materials in the select box for the given material_type dynfield

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

    {partner_email:text
        {label "Partner Email"}}

    {roommates:text(textarea)
        {label "Roommates"}
        {html "rows 4 cols 30"}}

    {accepted_terms_p:boolean(checkbox)
        {label "Terms & Conditions"}
        {options {{{<a href="https://www.startpage.com/">some text</a>} t}}}}

} -new_request {

    if { [set user_id [ad_conn user_id]] } {

        # If a registered user who is already registered for this event wants to register anew, redirect to edit the registration page
        set sql "select participant_id from im_event_participants where person_id=:user_id and project_id=:project_id"
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
             from im_event_participants ep 
             inner join parties pa on (pa.party_id=ep.person_id) 
             inner join persons p on (p.person_id=ep.person_id) 
             where participant_id=:participant_id"

    db_1row event_participant $sql

    set sql "select * from im_event_roommates where participant_id=:participant_id"
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

} -on_submit {
    
    if { [ad_form_new_p -key participant_id] } {
     
        set creation_ip [ns_conn peeraddr]
        set status_id ""
        set type_id ""
        set level ""

        db_transaction {

            db_exec_plsql insert_participant "select im_event_participant__new(

                :participant_id,

                :email,
                :first_names,
                :last_name,
                :creation_ip,

                :project_id,
                :status_id,
                :type_id,

                :lead_p,
                :partner_email,
                :accepted_terms_p,

                :accommodation,
                :food_choice,
                :bus_option,
                :level,
                
                :payment_type,
                :payment_term

            )"

            set roommate_emails [lsearch -all -inline -not [split $roommates ",| \t\n\r"] {}]

            foreach roommate_email $roommate_emails {
                db_exec_plsql insert_roommate "select im_event_roommate__new(
                    :participant_id,
                    :project_id,
                    :roommate_email
                )"
            }

            # for the participant's partner and everyone else who declared this person as their roommate,
            # we already do this but for the given participant we need to call it now,
            # after we have inserted his/her roommates in the db
            db_exec_plsql status_automaton "select im_event_participant__status_automaton(:participant_id)"

        }

    } else {
        error "pl/pgsql function im_event_participant__update not implemented yet"
    }

} -after_submit {
    ad_returnredirect [export_vars -base registration {participant_id}]
}



