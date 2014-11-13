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
    where material_type in ('Accomodation', 'Course Income', 'Bus Options', 'Food Choice')
"

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
            [list label [::flyhh::mc material_${material_id} ${material_name}]] \
            [list html "size 15"] \
            [list help_text "[format "%.2f" ${price}] $currency / ${uom_name}"]]

}


ad_form -extend -name $form_id -form $elements -validate {

    {event_name 
        {[db_string must_not_exist "select false from flyhh_events where event_name=:event_name" -default true]}
        {[::flyhh::mc event_name_exists "event name must be unique, given name already exists"]}}

}

ad_form -extend -name $form_id -edit_request {

    set sql "
        select *
        from flyhh_event_materials
        where event_id=:event_id
    "

    db_foreach material_capacity $sql {
        set varname capacity.$material_id
        set $varname $capacity
    }

    set sql "
        select *
        from flyhh_events evt
        inner join im_projects p on (p.project_id = evt.project_id)
        where event_id = :event_id
    "

    db_1row event_info $sql

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

    ad_returnredirect [export_vars -base event-one {event_id}]

}


