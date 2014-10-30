ad_page_contract {
    
    flying hamburger event add/edit/view page
    
    @author Neophytos Demetriou (neophytos@azet.sk)
    @creation-date 2014-10-15
    @last-modified 2014-10-30
    @cvs-id $Id$
} {
    event_id:integer,optional,notnull
} -properties {
} -validate {
} -errors {
}

set page_title "Event Form"
set context [ad_context_bar $page_title]

set form_id "event_form"
set action_url ""
set object_type "flyhh_event" ;# used for appending dynfields to form

if { [exists_and_not_null event_id] } {
    set mode display
} else {
    set mode edit
}

ad_form \
    -name $form_id \
    -action $action_url \
    -mode $mode \
    -form {

        event_id:key(acs_object_id_seq)

        {event_name:text
            {label "Name"}}

        {project_type_id:text(im_category_tree),optional 
            {label {[lang::message::lookup {} intranet-cust-flyhh.Project_Type "Project Type"]}}
            {custom {category_type "Intranet Project Type" translate_p 1 package_key "intranet-cust-flyhh"}} }
        
        {enabled_p:boolean(select)
            {label "Enable?"}
            {options {{Yes "t"} {No "f"}}}}

    }

im_dynfield::append_attributes_to_form \
    -object_type $object_type \
    -form_id $form_id \
    -object_id 0 \
    -advanced_filter_p 0

# Set the form values from the HTTP form variable frame
im_dynfield::set_form_values_from_http -form_id $form_id
im_dynfield::set_local_form_vars_from_http -form_id $form_id

ad_form -extend -name $form_id -select_query {

    select * from flyhh_events evt inner join im_projects p on (p.project_id = evt.project_id) where event_id=:event_id

} -new_data {

    # TODO: consider using the company_id that is associated with the connecting user
    set company_id 8720  ;# Flying Hamburger

    set project_nr [im_next_project_nr]

    set sql "
        select flyhh_event__new(
            :event_id,
            :event_name,
            :company_id,
            :project_nr,
            :project_type_id,
            :enabled_p
        );
    "

    db_exec_plsql insert_event $sql

} -edit_data {

    set sql "
        select flyhh_event__update(
            :event_id,
            :event_name,
            :company_id,
            :project_type_id
        );
    "

    db_exec_plsql update_event $sql

} -after_submit {

    ad_returnredirect [export_vars -base event-one {event_id}]

}


