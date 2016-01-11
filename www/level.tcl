ad_page_contract {
    
    Additional Level Questions, if needed
    
    
    @creation-date 2014-10-15
    @last-modified 2014-11-11
    @cvs-id $Id$
} {
    email:notnull
    level_token:notnull
    participant_id:integer,notnull
    token
} -properties {
}

set adp_master "master-bcc"
set locale "en_US"
# check that the token is correct
set check_token [ns_sha1 "${email}${participant_id}"]
if {$level_token ne $check_token} {
    set error_text "Illegal Token - You should not edit the link!"
}

db_1row participant_info "select ep.*, first_names, event_id from persons p, flyhh_event_participants ep, flyhh_events e where ep.participant_id = :participant_id and e.project_id = ep.project_id and ep.person_id = p.person_id"

set course_name [im_material_name -material_id $course]

# Check if the Project ID is valid
set event_name [db_string project "select event_name from flyhh_events where event_id = :event_id" -default ""]
if {$event_name eq ""} {
    set error_text "Illegal Event - $event_id is not an Event we know of"
} else {
    db_1row event_info "select project_cost_center_id, p.project_id, event_url, event_email, facebook_event_url,facebook_orga_url from flyhh_events f, im_projects p where event_id = :event_id and p.project_id = f.project_id"

    switch $project_cost_center_id {
        34915 {
	    if {$event_id eq 48362} {
		set adp_master "master-wscc"
	    } else {
		set adp_master "master-scc"
	    }
        }
        default {
            set adp_master "master-bcc"
        }
    }
}

set form_id "level_form"
set action_url ""

# Warning that all information needs to filled out with regards to dance selected

ad_form \
    -name $form_id \
    -action $action_url \
    -has_edit 1 \
    -mode edit \
    -export [list participant_id event_id token level_token email] \
    -form {
	{dance_location:text 
            {label {[::flyhh::mc dance_location "Where do you dance socially?"]}}
            {html {size 45}}
        }
	{dance_frequency_id:text(im_category_tree)
	    {label {[::flyhh::mc dance_frequency "How often do you dance socially"]}} 
	    {custom {category_type "Flyhh - Dance Frequency" translate_p 1 package_key "intranet-cust-flyhh"}}
        }
	{dance_duration_id:text(im_category_tree)
	    {label {[::flyhh::mc dance_duration "Since when are you dancing"]}} 
	    {custom {category_type "Flyhh - Dance Duration" translate_p 1 package_key "intranet-cust-flyhh"}}
        }
	{dance_local_classes:text(textarea),optional
	    {label {[::flyhh::mc dance_local_classes "How often do you take local classes? Enter the level and the name of the local teacher"]}}
	    {html "rows 4 cols 45"}
	}
	{dance_teaching:text(textarea),optional
            {label {[::flyhh::mc dance_teaching "Do you teach dancing? What type of dance and where?"]}}
            {html "rows 4 cols 45"}
        }
	{international_workshops:text(textarea),optional
	    {label {[::flyhh::mc international_workshops "Which international workshops have you taken in the past 18 months? Please provide the role, level and whether you were auditioned"]}}
            {html "rows 8 cols 45"}
        }
	{private_class:text(textarea),optional
            {label {[::flyhh::mc private_class "Have you taken a private class recently? With whom?"]}}
            {html "rows 4 cols 45"}
        }
	{other_dance_styles:text(textarea),optional
            {label {[::flyhh::mc other_dance_stypes "Do you have relevant experience with other dance styles? Please provide a brief summary"]}}
            {html "rows 8 cols 45"}
        }
	{primary_role_id:text(im_category_tree)
	    {label {[::flyhh::mc primary_role "Which role do you normally dance?"]}} 
	    {custom {category_type "Flyhh - Primary Role" translate_p 1 package_key "intranet-cust-flyhh"}}
        }
	{self_level_id:text(im_category_tree)
	    {label {[::flyhh::mc self_level "In which level do you see yourself"]}} 
	    {custom {category_type "Flyhh - Event Participant Level" translate_p 1 package_key "intranet-cust-flyhh"}}
        }
	{border_level_type_id:text(im_category_tree),optional
	    {label {[::flyhh::mc border_level_type "If you are on the border of two levels, what do you prefer?"]}} 
	    {custom {category_type "Flyhh - Border Level" translate_p 1 package_key "intranet-cust-flyhh"}}
        }
	{competitions:text(textarea),optional
            {label {[::flyhh::mc competitions "What competitions did you enter and where did you place?"]}}
            {html "rows 8 cols 45"}
        }
	{level_references:text(textarea),optional
            {label {[::flyhh::mc level_references "Can you name former participants of our castle camps who can confirm your level self assessment?"]}}
            {html "rows 8 cols 45"}
	    {help_text {[::flyhh::mc level_references_help "For advanced class we ask you to provide us two names (with E-Mail) of participants, for master track we ask you to provide one of our teachers as reference"]}}
        }
    } -on_request {
	db_0or1row level_info "select * from flyhh_event_participant_level where participant_id = :participant_id"
        set form_elements [template::form::get_elements $form_id]
        foreach element $form_elements {
            if { [info exists $element] } {
                set value [set $element]
                template::element::set_value $form_id $element $value
            }
        }
    } -on_submit {
	if {[db_string exists "select 1 from flyhh_event_participant_level where participant_id = :participant_id" -default 0]} {
	    db_dml update "update flyhh_event_participant_level set
		dance_location = :dance_location,
		dance_frequency_id = :dance_frequency_id,
		dance_duration_id = :dance_duration_id,
		dance_local_classes = :dance_local_classes,
		dance_teaching = :dance_teaching,
		international_workshops = :international_workshops,
		private_class = :private_class,
		other_dance_styles = :other_dance_styles,
		primary_role_id = :primary_role_id,
		self_level_id = :self_level_id,
		border_level_type_id = :border_level_type_id,
		competitions = :competitions,
		level_references = :level_references
		where participant_id = :participant_id"
	} else {
	    db_dml insert "insert into flyhh_event_participant_level (participant_id,dance_location,dance_frequency_id,dance_duration_id,dance_local_classes,dance_teaching,international_workshops,private_class,other_dance_styles,primary_role_id,self_level_id,border_level_type_id,competitions,level_references) values (:participant_id,:dance_location,:dance_frequency_id,:dance_duration_id,:dance_local_classes,:dance_teaching,:international_workshops,:private_class,:other_dance_styles,:primary_role_id,:self_level_id,:border_level_type_id,:competitions,:level_references)"
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

        set sql "select * from flyhh_event_roommates where participant_id=:participant_id"
        set roommates_text ""
        db_foreach roommate $sql {
            append roommates_text $roommate_email "\n"
        }

	if {$roommates_text ne ""} {
	    append body "<li>[::flyhh::mc Roommates "Roommates"]: $roommates_text</li>"
	}

	append body "</ul><b>Level Information</b><ul>"
	append body "<li>[::flyhh::mc dance_location "Where do you dance socially?"]: $dance_location</li>"
	append body "<li>[::flyhh::mc dance_frequency "How often do you dance socially"]: [im_category_from_id $dance_frequency_id]</li>"
	append body "<li>[::flyhh::mc dance_duration "Since when are you dancing"]: [im_category_from_id $dance_duration_id]</li>"
	if {$dance_local_classes ne ""} {
	    append body "<li>[::flyhh::mc dance_local_classes "How often do you take local classes? Enter the level and the name of the local teacher"]</li>"
	}
	if {$dance_teaching ne ""} {
	    append body "<li>[::flyhh::mc dance_teaching "Do you teach dancing? What type of dance and where?"]: $dance_teaching</li>"
	}
	if {$international_workshops ne ""} {
	    append body "<li>[::flyhh::mc international_workshops "Which international workshops have you taken in the past 18 months? Please provide the role, level and whether you were auditioned"]: $international_workshops</li>"
	}
	if {$private_class ne ""} {
	    append body "<li>[::flyhh::mc private_class "Have you taken a private class recently? With whom?"]: $private_class</li>"
	}
	if {$other_dance_styles ne ""} {
	    append body "<li>[::flyhh::mc other_dance_stypes "Do you have relevant experience with other dance styles? Please provide a brief summary"]: $other_dance_styles</li>"
	}
	if {$primary_role_id ne ""} {
	    append body "<li>[::flyhh::mc primary_role "Which role do you normally dance?"]: [im_category_from_id $primary_role_id]</li>"
	}
	if {$self_level_id ne ""} {
	    append body "<li>[::flyhh::mc self_level "In which level do you see yourself"]: [im_category_from_id $self_level_id]</li>"
	}
	if {$border_level_type_id ne ""} {
	    append body "<li>[::flyhh::mc border_level_type "If you are on the border of two levels, what do you prefer?"]: [im_category_from_id $border_level_type_id]</li>"
	}
	if {$competitions ne ""} {
	    append body "<li>[::flyhh::mc competitions "What competitions did you enter and where did you place?"]: $competitions</li>"
	}
	if {$level_references ne ""} {
	    append body "<li>[::flyhh::mc level_references "Can you name former participants of our castle camps who can confirm your level self assessment?"]: $level_references</li>"
	}
	append body "</ul>"

	# Cross Promotion for the other events
	# Get all the other events which are currently active to provide links
	set other_events_html ""
	db_foreach other_events "select event_id as other_event_id,event_name as other_event_name from flyhh_events e, im_projects p where e.project_id = p.project_id and p.project_status_id = [im_project_status_open] and event_id <> :event_id" {
	    set other_token [ns_sha1 "${email}${other_event_id}"]
	    append other_events_html "<li><b>$other_event_name: <a href='[export_vars -base "[ad_url]/flyhh/registration" -url {{token $other_token} email {event_id $other_event_id}}]'>Sign me up!</a></b></li>"
	}

	if {$other_events_html ne ""} {
	    append body "<h3>Can't get enough dancing? Sign up for our other events as well:</h3>
<ul>
$other_events_html
</ul>"
	}

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

