ad_page_contract {
    
    flying hamburger registration page
    
    @author Neophytos Demetriou (neophytos@azet.sk)
    @creation-date 2014-10-15
    @last-modified 2014-11-11
    @cvs-id $Id$
} {
    participant_id:integer,optional,notnull
    person_id:integer,optional,notnull
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
set return_url [ad_return_url]

set locale [lang::user::locale]
# TODO: token parameter is not meant to be optional
# it is going to be a signed key that helps us extract
# the project_id and it prevents sequential access
# to event registration pages. For debugging purposes,
# we use an arbitrary project_id that we create for
# company 8720, i.e. Flying Hamburger Events UG.
#
#set sql "select project_id from im_projects where project_type_id=102 and company_id=8720 limit 1"
#set project_id [db_string some_project_id $sql]

# Check if the Project ID is valid
set event_name [db_string project "select event_name from flyhh_events where project_id = :project_id" -default ""]
if {$event_name eq ""} {
    set error_text "Illegal Event - $event_id is not an Event we know of"
} else {
    db_1row event_info "select project_cost_center_id, p.project_id, event_url, event_email, project_name from flyhh_events f, im_projects p where p.project_id = :project_id and p.project_id = f.project_id"

    switch $project_cost_center_id {
        34915 {
            set adp_master "master-scc"
        }
        default {
            set adp_master "master-bcc"
        }
    }
}

set page_title "Registration Form"
set context_bar [ad_context_bar [list [export_vars -base "participants-list" -url {project_id}] $project_name] $page_title]

set form_id "registration_form"
set action_url ""
set object_type "flyhh_event_participant" ;# used for appending dynfields to form

if { [exists_and_not_null participant_id] } {
    set mode display
} else {
    set mode edit
}

set room_options [list [list "" ""]]

set room_sql "select room_name,e.room_id, office_name, sleeping_spots, material_name,
(select count(*) from flyhh_event_room_occupants ro where ro.room_id = e.room_id and ro.project_id = :project_id) as taken_spots
from flyhh_event_rooms e, im_offices o, im_projects p, im_materials m
where e.room_office_id = o.office_id
and o.company_id = p.company_id
and e.room_material_id = m.material_id
"

if {[exists_and_not_null participant_id]} {
    if {[db_0or1row room_id "select room_id, accommodation, alternative_accommodation from flyhh_event_participants ep left outer join flyhh_event_room_occupants ro on (ep.person_id = ro.person_id and ep.project_id = ro.project_id) where participant_id = :participant_id"]} {
	if {$room_id ne ""} {
	    db_1row room_info "select room_name,e.room_id, office_name, material_name
from flyhh_event_rooms e, im_offices o, im_materials m
where e.room_office_id = o.office_id
and e.room_material_id = m.material_id
and e.room_id = :room_id"
	    lappend room_options [list "$room_name ($office_name) - $material_name" $room_id]
	}
	set accommodation_ids [list $accommodation]
	foreach alt_accommodation_id $alternative_accommodation {
	    lappend accommodation_ids $alt_accommodation_id
	}
    
	# Get the possible accomodation_ids due to parent
	#db_foreach parent_ids "select parent_material_id from im_materials where material_id in ([template::util::tcl_to_sql_list $accommodation_ids])" {
	#if {$parent_material_id ne ""} {
	#lappend accommodation_ids $parent_material_id
	#}
	#}
	append room_sql "and e.room_material_id in ([template::util::tcl_to_sql_list $accommodation_ids])"
    }
}

db_foreach rooms $room_sql {
    if {$taken_spots < $sleeping_spots} {
	set available_spots [expr $sleeping_spots - $taken_spots]
        lappend room_options [list "$room_name ($office_name) - $material_name ($available_spots free)" $room_id]
    }
}

set room_options [lsort -unique $room_options]

ad_form \
    -name $form_id \
    -action $action_url \
    -mode $mode \
    -export [list project_id person_id] \
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
        
        {-section contact_details
            {legendtext {[::flyhh::mc Contact_Details_Section "Contact Details"]}}}
            
        {cell_phone:text,optional
            {label {[::flyhh::mc Phone "Cell Phone"]}}}
        
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

        {-section course_preferences
            {legendtext {[::flyhh::mc Course_Registration_Section "Course Information"]}}}

        {course:text(select)
            {label {[::flyhh::mc Course "Course"]}}
            {html {}}
            {options {[flyhh_material_options -project_id $project_id -material_type "Course Income" -locale $locale]}}
        }
        
        {lead_p:text(select)
            {label {[::flyhh::mc Lead_or_Follow "Lead/Follow"]}}
            {options {{"" ""} {Lead t} {Follow f}}}
        }    
        {level:text(im_category_tree),optional
            {label {[::flyhh::mc Level "Level"]}} 
            {custom {category_type "Flyhh - Event Participant Level" translate_p 1 package_key "intranet-cust-flyhh"}}}
        {partner_text:text,optional
            {label {[::flyhh::mc Partner "Partner"]}}
            {help_text {[::flyhh::mc partner_text_help "Please provide us with the email address of your partner so we can inform her/him and make sure both of you get the partner rebate"]}}
            {html {size 45}}
        }
                
        {-section accommodation_preferences
            {legendtext {[::flyhh::mc Accomodation_Registration_Section "Accommodation Information"]}}}
        {accommodation:text(select)
            {label {[::flyhh::mc Accommodation "Accommodation"]}}
            {html {}}
            {options {[flyhh_material_options -project_id $project_id -material_type "Accommodation" -locale $locale]}}
        }
        {alternative_accommodation:text(multiselect),multiple,optional
            {label {[::flyhh::mc Alternative_Accommodation "Alternative Accommodation"]}}
            {html {}}
            {options {[flyhh_material_options -project_id $project_id -material_type "Accommodation" -locale $locale]}}
            {help_text {[::flyhh::mc alt_accomm_help "Please provide us with other accommodation choices you are fine with in case your first choice isn't available. This will increase your chances of coming to our camp."]}}
        }
        	{room_id:text(select),optional
        	    {label {[::flyhh::mc Room "Room"]}}
        	    {options $room_options}
        	}
        {food_choice:text(select)
            {label {[::flyhh::mc Food_Choice "Food Choice"]}}
            {html {}}
            {options {[flyhh_material_options -project_id $project_id -material_type "Food Choice" -locale $locale]}}
        }
        {roommates_text:text(textarea),optional
            {label {[::flyhh::mc Roommates "Roommates"]}}
            {html "rows 4 cols 45"}
            {help_text "comma-separated list of email addresses, names, or both"}
        }
    }

if { [ad_form_new_p -key participant_id] } {
    ad_form -extend -name $form_id -form {
        {accommodation_text:text,optional
            {label {[::flyhh::mc Accommodation_Comments "Accommodation Comments"]}}
            {help_text {[::flyhh::mc bedmate_help "Please provide the email address of your partner whom you agreed with in advance to share a queen sized double bed with. Alternatively, please state 'female' or 'male' if you are fine sharing a double bed with a person of that gender. And if you have any other comments about the accomodation let us know as well :-)"]}}
            {html {style "width:300px;"}}
        }
    }
}

ad_form -extend -name $form_id -form {
        {-section event_preferences
            {legendtext {[::flyhh::mc Accomodation_Registration_Section "Other Information"]}}}
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
        {options {{{<a href="https://www.startpage.com/">I have read and accept the terms and conditions for this event</a>} t}}}
    }
} -new_request {

    if { [set user_id [ad_conn user_id]] && !$admin_p} {

        # If a registered user who is already registered for this event wants to register anew, redirect to edit the registration page
        set sql "select participant_id from flyhh_event_participants where person_id=:user_id and project_id=:project_id"
        set exists_participant_id [db_string registration_exists $sql -default ""]
        if { $exists_participant_id ne {} } {
            ad_returnredirect [export_vars -base registration { project_id { participant_id $exists_participant_id } }]
            return
        }
    }


    if {![info exists person_id]} {set person_id $user_id}

    # If a registered user who already has information in the system registers for a new event, pre fill the known information.
    set sql "
            select first_names, last_name, email 
            from parties pa 
            inner join persons p on (p.person_id=pa.party_id) 
            left outer join users_contact uc on (uc.user_id=pa.party_id)
            where person_id=:person_id"
    db_1row user_info $sql

    # Now find out the company information
    set company_id [db_string company_id "select max(object_id_one) from acs_rels where object_id_two = 33114 and rel_type = 'im_company_employee_rel'" -default ""]
    
    # Get address information
    db_0or1row addresses "select * from users_contact where user_id = :person_id"
    
} -edit_request {

    set sql "select ep.*, pa.*,p.*,uc.*,ro.room_id
             from flyhh_event_participants ep 
             inner join parties pa on (pa.party_id=ep.person_id) 
             inner join persons p on (p.person_id=ep.person_id) 
             inner join users_contact uc on (uc.user_id=ep.person_id)
             left outer join flyhh_event_room_occupants ro on (ep.person_id = ro.person_id and ep.project_id = ro.project_id) 
             where participant_id=:participant_id"

    db_1row event_participant $sql

    set roommates [db_list roommates "select roommate_email from flyhh_event_roommates where participant_id=:participant_id"]
    set roommates_text [join $roommates ", "]

    set company_id [db_string company_id "select	max(r.object_id_one)
from acs_rels r
where r.object_id_two=:person_id and r.rel_type = 'im_company_employee_rel'" -default ""]

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
        {[::flyhh::match_name_email $partner_text partner_name partner_email] || $partner_text eq ""}
        {[::flyhh::mc partner_text_validation_error "partner text must be an email address"]}
    }

} -new_data {
        
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
            -level $level \
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
} -edit_data {
        
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

        }        
    

} -after_submit {
    set person_id [db_string person_id "select person_id from flyhh_event_participants where participant_id = :participant_id"]
    db_dml delete_occupants "delete from flyhh_event_room_occupants where project_id = :project_id and person_id = :person_id"
    if {$room_id ne ""} {
	db_dml insert_occupant "insert into flyhh_event_room_occupants (room_id, person_id,project_id) values (:room_id, :person_id, :project_id)"
    }

    ad_returnredirect [export_vars -base registration {project_id participant_id}]
}

if {[exists_and_not_null participant_id]} {
    set person_id [db_string person_id "select person_id from flyhh_event_participants where participant_id = :participant_id"]

    set mail_url [export_vars -base "[apm_package_url_from_key "intranet-mail"]mail" -url {{object_id $participant_id} {party_ids $person_id} {subject "${project_name}: "} {from_addr $event_email} return_url}]
}

set left_navbar_html ""
set show_context_help_p 0

