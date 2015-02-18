ad_page_contract {

    flying hamburger registration link

    @author Malte Sussdorff
    @creation-date 2015-02-16
    @last-modified 2015-02-17
    @cvs-id $Id$
} {
    email:notnull
    event_id:integer,notnull
} -properties {
} -errors {
}

set error_text ""
# Check if the E-Mail is valid
set valid_email_p [acs_mail_lite::utils::valid_email_p $email]
if {!$valid_email_p} {
    set error_text "Illegal E-Mail - $email is not a valid email"
}

set adp_master "master-bcc"

# Check if the Project ID is valid
set event_name [db_string project "select event_name from flyhh_events where event_id = :event_id" -default ""]
if {$event_name eq ""} {
    set error_text "Illegal Event - $event_id is not an Event we know of"
} else {
    db_1row event_info "select project_cost_center_id, p.project_id, event_url, event_email from flyhh_events f, im_projects p where event_id = :event_id and p.project_id = f.project_id"
    
    switch $project_cost_center_id {
        34915 {
            set adp_master "master-scc"
        }
    }
}

if {$error_text eq ""} {
    
set mail_subject "Registration link for $event_name"
set mail_body ""

# Check if we have the E-Mail on record
set party_id [party::get_by_email -email $email]
if {$party_id ne ""} {
    # Directly send the party the registration link
    db_1row user_info "select first_names, last_name from persons where person_id = :party_id"
    set token [ns_sha1 "${party_id}${event_id}"]
    set registration_url [export_vars -base "[ad_url]/flyhh/registration" -url {token {user_id $party_id} event_id}]
    set mail_body "Dear $first_names, <p>You are almost done!<br />To register please click the following link:</p><p> <a href='$registration_url'>Register for $event_name</a></p><p>Your $event_name Crew.</p>"
    
    acs_mail_lite::send -send_immediately -to_addr $email -from_addr $event_email -use_sender -subject $mail_subject -body $mail_body -mime_type "text/html" -object_id $project_id
    
} else {
    
    unset party_id


    set form_id "registration_form"
    set action_url ""

    ad_form \
    -name $form_id \
    -action $action_url \
    -export event_id \
    -form {
        party_id:key(acs_object_id_seq)
        {email:text
            {label {[::flyhh::mc Participant_Email "Email"]}}}
        
        {first_names:text
            {label {[::flyhh::mc Participant_First_Name "First Name"]}}}
        
        {last_name:text
            {label {[::flyhh::mc Participant_Last_Name "Last Name"]}}
        }
    } \
    -on_request {
        set email $email
    } \
    -new_data {
        # Create the user and then send the E-Mail
        
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
        
        set user_id $creation_info(user_id)

        # Set the locale from the E-Mail Address.. Crude guess
        set ha_country_code [lindex [split $email "."] end]
        if {$ha_country_code eq "de"} {
           lang::user::set_locale -user_id $user_id "de_DE"
        } else {
           lang::user::set_locale -user_id $user_id "en_US"            
        }
    } \
    -after_submit {
        ad_returnredirect [export_vars -base "get-registration-link" -url {email event_id}]
    }
}

}