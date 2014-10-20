ad_page_contract {
    
    flying hamburger registration page
    
    @author Neophytos Demetriou (neophytos@azet.sk)
    @creation-date 2014-10-15
    @last-modified 2014-10-20
    @cvs-id $Id$
} {
    project_type_id:integer
} -properties {
} -validate {
} -errors {
}


set page_title "Registration Form"
set context [ad_context_bar "Registration Form"]

set form_id "registration_form"
set action_url ""
set object_type "im_event_participant" ;# used for appending dynfields to form

ad_form \
    -name $form_id \
    -action $action_url \
    -form {
	user_id:key(acs_object_id_seq)

	{first_name:text
	    {label "First Name"}
	}
	
	{last_name:text
	    {label "Last Name"}
	}
}



if {1} {

    # TODO: figure out how to filter materials in the select box for the given material_type dynfield

    im_dynfield::append_attributes_to_form \
        -object_type $object_type \
        -form_id $form_id \
        -object_id 0 \
        -advanced_filter_p 0

    # Set the form values from the HTTP form variable frame
    #im_dynfield::set_form_values_from_http -form_id $form_id
    #im_dynfield::set_local_form_vars_from_http -form_id $form_id
}
