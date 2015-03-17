ad_page_contract {
    
    flying hamburger registration page
    
    @author Neophytos Demetriou (neophytos@azet.sk)
    @creation-date 2014-10-15
    @last-modified 2014-11-11
    @cvs-id $Id$
} {
    event_id:integer,notnull
    email:notnull
    {inviter_text:trim ""}
    token:notnull
    alternative_accommodation:multiple,optional
} -properties {
}


set error_text ""
set adp_master "master-bcc"
set locale "en_US"

# Check if the Project ID is valid
set event_name [db_string project "select event_name from flyhh_events where event_id = :event_id" -default ""]
if {$event_name eq ""} {
    set error_text "Illegal Event - $event_id is not an Event we know of"
} else {
    db_1row event_info "select project_cost_center_id, p.project_id, event_url, event_email, facebook_event_url,facebook_orga_url from flyhh_events f, im_projects p where event_id = :event_id and p.project_id = f.project_id"

    switch $project_cost_center_id {
        34915 {
            set adp_master "master-scc"
        }
        default {
            set adp_master "master-bcc"
        }
    }
}

# check that the token is correct
set check_token [ns_sha1 "${email}${event_id}"]
if {$token ne $check_token} {
    set error_text "Illegal Token - You should not edit the link!"
}

############ CHANGE THIS #####################

if {$error_text ne ""} {
    ad_return_error "Error in URL" "$error_text"
} else {
    set form_id "registration_form"
    set action_url ""
    
    set user_id [party::get_by_email -email $email]
    set ha_country_code [lindex [split $email "."] end]

    if {$user_id ne ""} {
        # Set the locale for the user
        set locale [lang::user::locale -user_id $user_id]
    } else {
        # Set the locale from the E-Mail Address.. Crude guess
        if {$ha_country_code eq "de"} {
            set site_wide_locale "de_DE"
        } else {
            set site_wide_locale "en_US"
        }
    }
    ad_conn -set locale $locale
    
    # If a registered user who is already registered for this event wants to register anew, redirect to edit the registration page
    set sql "select participant_id from flyhh_event_participants where person_id=:user_id and project_id=:project_id"
    set participant_id [db_string registration_exists $sql -default ""]

    if { [exists_and_not_null participant_id] } {
        set mode display
    } else {
        set mode edit
        unset participant_id
    }

    ad_form \
    -name $form_id \
    -action $action_url \
    -mode $mode \
    -has_edit 1 \
    -export [list project_id event_id token inviter_text] \
    -form {

        participant_id:key(acs_object_id_seq)

        {-section basic_info
            {legendtext {[::flyhh::mc Basic_Info_Section "Basic Info"]}}}

        {email:text(inform)
            {label {[::flyhh::mc Participant_Email "Email"]}}
            {value "$email"}
        }

        {first_names:text
            {label {[::flyhh::mc Participant_First_Name "First Name"]}}}
        
        {last_name:text
            {label {[::flyhh::mc Participant_Last_Name "Last Name"]}}}
        
        {-section contact_details
            {legendtext {[::flyhh::mc Contact_Details_Section "Contact Details"]}}}
            
        {ha_line1:text
            {label {[::flyhh::mc Address_Line_1 "Address Line 1"]}}
            {html {size 45}}
        }
        {ha_city:text
            {label {[::flyhh::mc City "City"]}}
            {html {size 30}}
        }
        
        {ha_state:text,optional
            {label {[::flyhh::mc State "State"]}}
            {html {size 5}}
        }
        
        {ha_postal_code:text
            {label {[::flyhh::mc Postal_code "Postal Code"]}}
            {html {size 10}}
        }
        
        {ha_country_code:text(select)
            {label {[::flyhh::mc Country "Country"]}}
            {html {}}
            {options {[im_country_options]}}
        }
        {cell_phone:text,optional
            {label {[::flyhh::mc Phone "Cell Phone"]}}}
        
        {-section course_preferences
            {legendtext {[::flyhh::mc Course_Registration_Section "Course Information"]}}}

    }

    if {$inviter_text eq ""} {
        ad_form -extend -name $form_id -form {
            {course:text(select)
                {label {[::flyhh::mc Course "Course"]}}
                {html {}}
                {options {[flyhh_material_options -project_id $project_id -material_type "Course Income" -locale $locale]}}
            }
    
            {lead_p:text(select)
                {label {[::flyhh::mc Lead_or_Follow "Lead/Follow"]}}
                {options {{"" ""} {Lead t} {Follow f}}}
            }    
            {partner_text:text,optional
                {label {[::flyhh::mc Partner "Partner"]}}
                {help_text {[::flyhh::mc partner_text_help "Please provide us with the email address of your partner so we can inform her/him and make sure both of you get the partner rebate"]}}
                {html {size 45}}
            }
        }
    } else {
        ad_form -extend -name $form_id -form {
            {course:text(select)
                {label {[::flyhh::mc Course "Course"]}}
                {html {}}
                {mode display}
                {options {[flyhh_material_options -project_id $project_id -material_type "Course Income" -locale $locale]}}
            }
            {lead_p:text(select)
                {label {[::flyhh::mc Lead_or_Follow "Lead/Follow"]}}
                {mode display}
                {options {{"" ""} {Lead t} {Follow f}}}
            }    
            {partner_text:text(inform)
                {label {[::flyhh::mc Partner "Partner"]}}
                {value "${inviter_text}"}
                {help_text {[::flyhh::mc partner_text_present_help "Your partner invited you to the event, so you are unable to change the course, role and partner."]}}
            }
        }
    }
    
    ad_form -extend -name $form_id -form {
        {-section accommodation_preferences
            {legendtext {[::flyhh::mc Accomodation_Registration_Section "Accommodation Information"]}}}
        {accommodation:text(select)
            {label {[::flyhh::mc Accommodation "Accommodation"]}}
            {html {}}
            {options {[flyhh_accommodation_options -project_id $project_id -locale $locale]}}
        }
        {alternative_accommodation:text(multiselect),multiple,optional
            {label {[::flyhh::mc Alternative_Accommodation "Alternative Accommodation"]}}
            {html {}}
            {options {[flyhh_accommodation_options -project_id $project_id -locale $locale]}}
            {help_text {[::flyhh::mc alt_accomm_help "Please provide us with other accommodation choices you are fine with in case your first choice isn't available. This will increase your chances of coming to our camp."]}}
        }
        {food_choice:text(select)
            {label {[::flyhh::mc Food_Choice "Food Choice"]}}
            {html {}}
            {options {[flyhh_material_options -project_id $project_id -material_type "Food Choice" -locale $locale]}}
        }
        {roommates_text:text(textarea),optional
            {label {[::flyhh::mc Roommates "Roommates"]}}
            {html "rows 4 cols 45"}
            {help_text {[::flyhh::mc roommates_text_help "Comma-separated list of email addresses"]}}
        }
    }

    if { [ad_form_new_p -key participant_id] } {
        ad_form -extend -name $form_id -form {
            {accommodation_text:text(textarea),optional
                {label {[::flyhh::mc Accommodation_Comments "Accommodation Comments"]}}
                {html "rows 4 cols 45"}
                {help_text {[::flyhh::mc bedmate_help "Please let us know if you are fine to share a double bed with another person (male, female), have a special someone whom you want to share your bed with or any other comments regarding accommodation."]}}
                {html {style "width:300px;"}}
            }
        }
    }

    ad_form -extend -name $form_id -form {
        {-section event_preferences
            {legendtext {[::flyhh::mc Event_Preference_Registration_Section "Other Information"]}}}
        {bus_option:text(select),optional
            {label {[::flyhh::mc Bus_Option "Bus Option"]}}
            {html {}}
            {options {[flyhh_material_options -project_id $project_id -material_type "Bus Options" -locale $locale]}}
        }
    }
    
    set new_request_p 0

    if { [ad_form_new_p -key participant_id] } {
        set new_request_p 1
        ad_form -extend -name $form_id -form {
            {skills:text(textarea),optional
                {label {[::flyhh::mc Skills "Skills"]}}
                {html "rows 4 cols 45"}
                {help_text {[::flyhh::mc skills_help "Please provide us with some of your skills"]}}
            }
            {comments:text(textarea),optional
                {label {[::flyhh::mc Comments "Further Comments"]}}
                {html "rows 4 cols 45"}
                {help_text {[::flyhh::mc comments_help "Do you have any further comments for us?"]}}
            }
        }
    }

    ad_form -extend -name $form_id -form {
        {accepted_terms_p:boolean(checkbox)
            {label {[::flyhh::mc Terms_and_Conditions "Terms & Conditions"]}}
            {options {{{[::flyhh::mc accepted_conditions "I have read and accept the terms and conditions for this event"]} t}}}
            {help_text {You can find the terms at <a href='${event_url}/terms.php'>${event_url}/terms.php</A>}}
        }
    } -new_request {
        # If a registered user who already has information in the system registers for a new event, pre fill the known information.
        if {$user_id ne ""} {
            set sql "
            select first_names, last_name 
            from parties pa 
            inner join persons p on (p.person_id=pa.party_id) 
            left outer join users_contact uc on (uc.user_id=pa.party_id)
            where person_id=:user_id"
            db_1row user_info $sql

	    db_0or1row company_info "select address_line1 as ha_line1, address_city as ha_city, address_postal_code as ha_postal_code,address_country_code as ha_country_code, address_state as ha_state from im_offices, im_companies where office_id = main_office_id and primary_contact_id = :user_id limit 1"
        }
        
        if {$inviter_text ne ""} {
            # Load the data from the partner
            ::flyhh::match_name_email $inviter_text partner_name partner_email
            db_1row default_to_partner "select course,lead_p,accommodation from flyhh_event_participants e, parties p where project_id = :project_id and e.person_id = p.party_id and lower(p.email)=lower(:partner_email) limit 1"
            if {$lead_p == t} {set lead_p f} else {set lead_p t}
        }
        set ha_country_code [lindex [split $email "."] end]
        if {$ha_country_code eq "com"} {set ha_country_code ""}
    } -edit_request {

        set sql "select uc.*,pa.*,p.*,ep.*
             from flyhh_event_participants ep 
             inner join parties pa on (pa.party_id=ep.person_id) 
             inner join persons p on (p.person_id=ep.person_id) 
             inner join users_contact uc on (uc.user_id=ep.person_id)
             where participant_id=:participant_id"

        db_1row event_participant $sql

        set sql "select * from flyhh_event_roommates where participant_id=:participant_id"
        set roommates_text ""
        db_foreach roommate $sql {
            append roommates_text $roommate_email "\n"
        }

        set form_elements [template::form::get_elements $form_id]
        foreach element $form_elements {
            if { [info exists $element] } {
                set value [set $element]
                template::element::set_value $form_id $element $value
            }
        }

        set package_id [ad_conn package_id]


    } -validate {

        {partner_text
            {[::flyhh::match_name_email $partner_text partner_name partner_email] || $partner_text eq ""}
            {[::flyhh::mc partner_text_validation_error "partner text must be an email address, full name, or both"]}}
        {roommates_text
            {[::flyhh::valid_roommates_p -roommates_text $roommates_text]}
            {[::flyhh::mc invalid_roommate "Your list does not contain E-Mail addresses or names we can use. Please correct"]}
        }

    } -new_data {
        
        # Unset the partner in case we have solo material
        if {[db_string course_material "select 1 from im_materials where material_id = :course and lower(material_nr) like '%- solo%'" -default "0"]} {
            set partner_text ""
        }

        ::flyhh::create_participant \
            -participant_id $participant_id \
            -project_id $project_id \
            -email $email \
            -first_names $first_names \
            -last_name $last_name \
            -accepted_terms_p $accepted_terms_p \
            -course $course \
            -accommodation $accommodation \
            -alternative_accommodation $alternative_accommodation \
            -food_choice $food_choice \
            -bus_option $bus_option \
            -level "" \
            -lead_p $lead_p \
            -payment_type 804 \
            -payment_term "80107" \
            -partner_text $partner_text \
            -roommates_text $roommates_text \
            -cell_phone $cell_phone \
            -ha_line1 $ha_line1 \
            -ha_city $ha_city \
            -ha_state $ha_state \
            -ha_postal_code $ha_postal_code \
            -ha_country_code $ha_country_code

            
        # Deal with the comments as notes
        set person_id [db_string person_id "select person_id from flyhh_event_participants where participant_id = :participant_id"]
        if {$skills ne ""} {
            set skills [list [string trim $skills] "text/plain"]
            set skill_note_id [db_exec_plsql create_note "
                SELECT im_note__new(
                    NULL,
                    'im_note',
                    now(),
                    :person_id,
                    '[ad_conn peeraddr]',
                    null,
                    :skills,
                    :participant_id,
                    [im_note_type_skill],
                    [im_note_status_active]
                )
                "]
        }
        
        if {$comments ne ""} {
            set comments [list [string trim $comments] "text/plain"]
            set comment_note_id [db_exec_plsql create_note "
                SELECT im_note__new(
                    NULL,
                    'im_note',
                    now(),
                    :person_id,
                    '[ad_conn peeraddr]',
                    null,
                    :comments,
                    :participant_id,
                    [im_note_type_other],
                    [im_note_status_active]
                )
                "]            
        }
                    
        if {$accommodation_text ne ""} {
            set accommodation_text [list [string trim $accommodation_text] "text/plain"]
            set accommodation_note_id [db_exec_plsql create_note "
                SELECT im_note__new(
                    NULL,
                    'im_note',
                    now(),
                    :person_id,
                    '[ad_conn peeraddr]',
                    null,
                    :accommodation_text,
                    :participant_id,
                    [im_note_type_accommodation],
                    [im_note_status_active]
                )
                "]
        }
        
        if {$inviter_text eq ""} {
            # When you submit the registration and the dance partner did not register, send the dance partner an E-Mail (text
            # does not matter now) with a link to the registration for the event and the partner who asked them to join, so this
            # is already pre-filled?
            
            ::flyhh::match_name_email "$partner_text" partner_name partner_email
            
            if {$partner_email ne ""} {
            		# Check if the partner is already registered
            		set partner_registered_p [db_string parnter "select 1 from flyhh_event_participants e, parties p where project_id = :project_id and e.person_id = p.party_id and email = :partner_email" -default 0]
            		if {!$partner_registered_p} {
            		    ::flyhh::send_invite_partner_mail \
            			-participant_id $participant_id \
            			-participant_person_name "$first_names $last_name" \
            			-participant_email $email \
            			-event_id $event_id \
            			-event_name $event_name \
            			-from_addr $event_email \
            			-partner_email $partner_email \
            			-project_id $project_id
            		}
        	    }
        }    
    } -after_submit {
	set from_addr "$event_email"
	set to_addr ${email}
	set mime_type "text/html"
	set subject "Thank you for registering for $event_name"
	set body "Hi $first_names,
         <p>
         Thanks for registering to $event_name. We have received your registration and will send you a confirmation E-Mail once we have found a spot for you. This is NOT a confirmation, please wait with booking flights and travel arrangements until we can confirm we found a place for you.
         [_ intranet-cust-flyhh.lt_Heres_what_you_have_s]
        </p>
        <ul>
         "

	if {$course ne ""} {
	    append body "<li>[_ intranet-cust-flyhh.Course]: [db_string material_course "select material_name from im_materials where material_id = $course" -default ""]"
	    if {$lead_p} {append body " (LEAD)</li>"} else {append body " (FOLLOW)</li>"}
	}
	if {$accommodation ne ""} {
	    append body "<li>[_ intranet-cust-flyhh.Accommodation]: [db_string material_course "select material_name from im_materials where material_id = $accommodation" -default ""]</li>"
	}
	if {$food_choice ne ""} {
	    append body "<li>[_ intranet-cust-flyhh.Food_Choice]: [db_string material_course "select material_name from im_materials where material_id = $food_choice" -default ""]</li>"
	}
	if {$bus_option ne ""} {
	    append body "<li>[_ intranet-cust-flyhh.Bus_Option]: [db_string material_course "select material_name from im_materials where material_id = $bus_option" -default ""]</li>"
	}
	if {$partner_text ne ""} {
	    append body "<li>[::flyhh::mc Partner "Partner"]: $partner_text</li>"
	} 
	if {$roommates_text ne ""} {
	    append body "<li>[::flyhh::mc Roommates "Roommates"]: $roommates_text</li>"
	} 
	append body "</ul>"

	acs_mail_lite::send \
	    -send_immediately \
	    -from_addr $from_addr \
	    -to_addr $to_addr \
	    -subject $subject \
	    -body $body \
	    -mime_type $mime_type \
	    -object_id $project_id
	

        ad_returnredirect [export_vars -base registration {event_id participant_id email token}]
    }

}
