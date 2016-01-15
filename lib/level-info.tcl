if {![info exists participant_id]} {
	ad_page_contract {
		@author malte.sussdorff@cognovis.de
	} {
	   participant_id:integer
	}
}

# Warning that all information needs to filled out with regards to dance selected
set form_id "level-info"

ad_form \
    -name $form_id \
    -has_edit 1 \
    -mode display \
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
    }

