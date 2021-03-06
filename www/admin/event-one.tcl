ad_page_contract {
    
    flying hamburger event add/edit/view page
    
    @author Neophytos Demetriou (neophytos@azet.sk)
    @creation-date 2014-10-15
    @last-modified 2014-10-30
    @cvs-id $Id$
} {
    event_id:integer,optional,notnull
    project_type_id:integer,optional,notnull
} -properties {
} -validate {
} -errors {
}

if {![info exists project_type_id]} {
    set project_type_id [im_id_from_category "Event" "Intranet Project Type"]
}

set page_title "Event Form"
set context ""
set context_bar [ad_context_bar $page_title]

set form_id "event_form"
set action_url ""
set object_type "flyhh_event" ;# used for appending dynfields to form

if { [exists_and_not_null event_id] } {
    set mode display
} else {
    set mode edit
}
# TODO: disable cost_center_id when editing form
ad_form \
    -name $form_id \
    -action $action_url \
    -mode $mode \
    -form {

        event_id:key(acs_object_id_seq)
        {-section event_info 
            {legendtext {[::flyhh::mc Event_Info "Event Info"]}}}

        {event_name:text
            {label {[::flyhh::mc Event_Name "Name"]}}}

        {event_url:text
            {label {[::flyhh::mc Event_URL "URL"]}}}

        {facebook_event_url:text,optional
            {label {[::flyhh::mc facebook_event_url "Facebook Event URL"]}}
            {help_text {[::flyhh::mc event_fb_id_ht "Please enter the Facebook URL to your Event. If unsure, open your event in facebook and copy the URL"]}}
        }
        
        {facebook_orga_url:text,optional
            {label {[::flyhh::mc facebook_orga_url "Facebook Organization URL"]}}
            {help_text {[::flyhh::mc fb_orga_ht "Please enter the Facebook URL to your Organization where people can follow you for updates"]}}
        }
                
        {event_email:text
            {label {[::flyhh::mc Event_E-Mail "Sender E-Mail"]}}
        }

        {start_date:date(date)
            {label {[::flyhh::mc Event_Start_date "Start Date"]}}
            {format "YYYY-MM-DD"} 
            {after_html {<input type="button" style="height:23px; width:23px; background: url('/resources/acs-templating/calendar.gif');" onclick ="return showCalendarWithDateWidget('start_date', 'y-m-d');" >}}
        }
	
	{project_type_id:text(im_category_tree)
	    {label {Project Type}} 
	    {custom {category_type "Intranet Project Type" translate_p 1 package_key "intranet-cust-flyhh"}}
        }

        {project_cost_center_id:text(generic_sql)
            {label {[::flyhh::mc Project_Cost_Center "Project Cost Center"]}}
            {html {}}
            {custom {sql {select cost_center_id,cost_center_code || ' - ' || cost_center_name from im_cost_centers}}}}
        
        {enabled_p:boolean(select)
            {label {[::flyhh::mc Enable_Event "Enable?"]}}
            {options {{Yes "t"} {No "f"}}}}

        {-section ""}

    }

im_dynfield::append_attributes_to_form \
    -object_type $object_type \
    -form_id $form_id \
    -object_id 0 \
    -advanced_filter_p 0

# Set the form values from the HTTP form variable frame
im_dynfield::set_form_values_from_http -form_id $form_id
im_dynfield::set_local_form_vars_from_http -form_id $form_id


set sql "
    select *, im_name_from_id(uom_id) as uom_name 
    from im_timesheet_prices itp 
    inner join im_materials m on (m.material_id=itp.material_id) 
    inner join im_material_types mt on (m.material_type_id=mt.material_type_id) 
    where material_type in ('Accommodation', 'Course Income', 'Bus Options', 'Food Choice')
"

if {[exists_and_not_null event_id]} {
    db_0or1row project_id "select p.project_id, project_type_id from flyhh_events fe, im_projects p where fe.project_id = p.project_id and fe.event_id = :event_id"
}

append sql "and (itp.task_type_id is null or itp.task_type_id = :project_type_id)"

append sql "order by mt.material_type_id,itp.uom_id,material_name"

set section ""

db_foreach material_id $sql {

    if { $section ne $material_type_id } {

        set section $material_type_id

        set legendtext "Capacity for \"$material_type\" materials"

        lappend elements [list -section $material_type_id [list legendtext $legendtext]]

    }


    set varname "capacity.${material_id}"

    lappend elements \
        [list ${varname}:text,optional \
            [list label "${material_name}"] \
            [list html "size 15"] \
            [list help_text "[format "%.2f" ${price}] $currency / ${uom_name}"]]

}


ad_form -extend -name $form_id -form $elements -validate {

    {event_name 
        {[db_string must_not_exist "select false from flyhh_events where event_name=:event_name and event_id != :event_id" -default true]}
        {[::flyhh::mc event_name_exists "event name must be unique, given name already exists"]}}

}

ad_form -extend -name $form_id -edit_request {

    set sql "
        select *
        from flyhh_event_materials
        where event_id=:event_id
    "

    db_foreach material_capacity $sql {
        set varname capacity.${material_id}
        set $varname $capacity
    }

    set sql "
        select evt.*,p.project_id,p.project_cost_center_id,to_char(p.start_date,'YYYY-MM-DD') as ansi_start_date
        from flyhh_events evt
        inner join im_projects p on (p.project_id = evt.project_id)
        where event_id = :event_id
    "

    db_1row event_info $sql
    set start_date [template::util::date::from_ansi $ansi_start_date "YYYY-MM-DD"]
    
} -new_data {

    db_transaction {

        set provider_company_id 8720  ;# Flying Hamburger

        set project_nr [im_next_project_nr]

        set sql "
            select flyhh_event__new(
                :event_id,
                :event_name,
                :provider_company_id,
                :project_nr,
                :project_cost_center_id,
                :enabled_p
            );
        "

        db_exec_plsql insert_event $sql
        
        # The form has an input field (named capacity.material_id) 
        # for each material of the following types: Course Income,
        # Accomodation, Food Choice, Bus Options.

        foreach varname [info vars capacity.*] {

            set capacity [set $varname]

            set material_id [lindex [split $varname {.}] 1]

            set sql "
                insert into flyhh_event_materials (
                    event_id,
                    material_id,
                    capacity
                ) values (
                    :event_id,
                    :material_id,
                    :capacity
                )
            "

            db_dml insert_material_capacity $sql

        }

    }

} -edit_data {

    db_transaction {
        
        set sql "
            select flyhh_event__update(
                :event_id,
                :event_name,
                :project_cost_center_id,
                :enabled_p
            );
        "

        db_exec_plsql update_event $sql

        # Note that we have to preserve the number of occupied slots while
        # updating the capacity of each material for the given event, or
        # disallow updating the capacity once we start accepting regisrations
        # for the event.
        
        set sql "delete from flyhh_event_materials where event_id=:event_id"

        db_dml delete_old_capacity_rows $sql

	db_dml update_project "update im_projects set project_type_id = :project_type_id where project_id = (select project_id from flyhh_events where event_id = :event_id)"

        # The form has an input field (named capacity.material_id) 
        # for each material of the following types: Course Income,
        # Accomodation, Food Choice, Bus Options.

        foreach varname [info vars capacity.*] {

            set capacity [set $varname]

            set material_id [lindex [split $varname {.}] 1]

            set sql "
                insert into flyhh_event_materials (
                    event_id,
                    material_id,
                    capacity
                ) values (
                    :event_id,
                    :material_id,
                    :capacity
                )
            "

            db_dml insert_material_capacity $sql

        }

    }

} -after_submit {

    # Update url and e-mail
    db_dml update "update flyhh_events set event_url = :event_url, event_email = :event_email, facebook_event_url = :facebook_event_url, facebook_orga_url = :facebook_orga_url where event_id = :event_id"
    set start_date_sql [template::util::date get_property sql_date $start_date]
    db_dml update "update im_projects set start_date = $start_date_sql where project_id = (select project_id from flyhh_events where event_id = :event_id)"

    ad_returnredirect [export_vars -base event-one {event_id}]

}


