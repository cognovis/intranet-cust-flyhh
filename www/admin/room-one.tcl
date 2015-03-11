ad_page_contract {
    
    flying hamburger room add/edit/view page
    
    @author malte.sussdorff@cognovis.de
    @creation-date 2015-03-10 
} {
    {filter_project_id ""}
    room_id:integer,optional,notnull
    {return_url ""}
} -properties {
} -validate {
} -errors {
}

set page_title "Room Form"
set context ""
set context_bar [ad_context_bar [list "[export_vars -base "/flyhh/admin/rooms-list" -url {filter_project_id}]" [::flyhh::mc Rooms "Rooms"]] $page_title]

set form_id "room_form"
set action_url ""
set object_type "flyhh_event_room" ;# used for appending dynfields to form

if { [exists_and_not_null room_id] } {
    set mode display
} else {
    set mode edit
}

set material_options [list]

db_foreach materials {
    SELECT m.material_id,material_name
    FROM im_materials m 
    WHERE m.material_type_id=(SELECT material_type_id FROM im_material_types WHERE material_type='Accommodation')
    and material_status_id = 9100
} {
    lappend material_options [list $material_name $material_id]
}

set office_options [list]

db_foreach materials {
    SELECT office_id,office_name
    FROM im_offices o
    WHERE office_type_id = 175;
} {
    lappend office_options [list $office_name $office_id]
}

# TODO: disable cost_center_id when editing form
ad_form \
    -name $form_id \
    -action $action_url \
    -mode $mode \
    -export {return_url} \
    -form {

        room_id:key(acs_object_id_seq)
        {room_name:text
            {label {[::flyhh::mc room_Name "Name"]}}
        }
        {room_material_id:text(select)
            {label {[::flyhh::mc room_type "Room Type"]}}
            {html {}}
            {options {$material_options}}
        }
        {room_office_id:text(select)
            {label {[::flyhh::mc room_location "Room Location"]}}
            {html {}}
            {options {$office_options}}
        }
        {sleeping_spots:text(inform)
            {label {[::flyhh::mc room_sleeping_spots "Sleeping Spots"]}}
        }
        {single_beds:text,optional
            {html {size 3}}
            {label {[::flyhh::mc room_single_beds "Single Beds"]}}
        }
        {double_beds:text,optional
            {html {size 3}}
            {label {[::flyhh::mc room_double_beds "Double Beds"]}}
        }
        {additional_beds:text,optional
            {html {size 3}}
            {label {[::flyhh::mc room_additional_beds "Additional Beds"]}}
            {help_text {[::flyhh::mc room_additional_beds_help "This is the number of additional beds/mattresses which might be moved into this room"]}}
        }
        {toilet_p:boolean(checkbox),optional
            {label {[::flyhh::mc room_toilet "Toilet ?"]}}
            {options {{"" t}}}
        }
        {bath_p:boolean(checkbox),optional
            {label {[::flyhh::mc room_bath "Bath/Shower ?"]}}
            {options {{"" t}}}
        }
        {description:richtext(richtext),optional
            {label {[::flyhh::mc room_description "Description"]}}
            {html {cols 40} {rows 8} }
        }
    }


ad_form -extend -name $form_id -edit_request {

    set sql "
        select *
        from flyhh_event_rooms where room_id = :room_id
    "

    db_1row room_info $sql

} -new_data {

    db_transaction {

        set room_id [db_string room_id "select im_biz_object__new (
            :room_id,
            'flyhh_event_room',  -- object_type
            CURRENT_TIMESTAMP,   -- creation_date
            [ad_conn user_id],                -- creation_user
            NULL,
            NULL                        -- context_id
        )" -default $room_id]
        
        set sleeping_spots [expr $single_beds + $additional_beds + $double_beds * 2]
        db_dml insert_room {
            insert into flyhh_event_rooms (
                room_id,
                room_name,
                room_material_id,
                room_office_id,
                sleeping_spots,
                single_beds,
                double_beds,
                additional_beds,
                toilet_p,
                bath_p,
                description
            ) values (
                :room_id,
                :room_name,
                :room_material_id,
                :room_office_id,
                :sleeping_spots,
                :single_beds,
                :double_beds,
                :additional_beds,
                :toilet_p,
                :bath_p,
                :description            
            )
        }
    }

} -edit_data {

    set sleeping_spots [expr $single_beds + $additional_beds + $double_beds * 2]

    db_dml update_room {
        update flyhh_event_rooms set room_name = :room_name, room_material_id = :room_material_id, sleeping_spots = :sleeping_spots,
            single_beds = :single_beds, double_beds = :double_beds, additional_beds = :additional_beds, 
            toilet_p = :toilet_p, bath_p = :bath_p, description = :description, room_office_id = :room_office_id
        where room_id = :room_id
    }
    

} -after_submit {

    if {$return_url eq ""} {
        ad_returnredirect [export_vars -base room-one {room_id}]    
    } else {
        ad_returnredirect $return_url
    }

}

if {$mode eq "display"} {
    
    set event_options [list [list "" ""]]
    db_foreach events "
        select p.project_id,project_name 
        from im_projects p, flyhh_events e 
        where project_status_id = [im_project_status_open] 
        and p.project_id = e.project_id
    " {
        lappend event_options [list $project_name $project_id]
    }
    
    ad_form \
    -name "flyhh_event_room_filter" \
    -action "room-one" \
    -mode edit \
    -method GET \
    -export {room_id} \
    -form {
        {filter_project_id:text(select),optional
            {label {[::flyhh::mc Event "Event"]}}
            {html {}}
            {options {$event_options}}
            {values $filter_project_id}
        }
    } -on_submit {
    
        foreach varname {room_office_id room_material_id } {
    
            if { [exists_and_not_null $varname] } {
    
                set value [set $varname]
                set quoted_value [ns_dbquotevalue $value]
                append extra_where_clause "and $varname = $quoted_value" 
    
            }
    
        }
    
    }
    
    
    # Filter (possibly) later on
    # Compile and execute the formtemplate if advanced filtering is enabled.
    eval [template::adp_compile -string {<formtemplate id="flyhh_event_room_filter" style="tiny-plain-po"></formtemplate>}]
    set filter_html $__adp_output
    
    # Left Navbar is the filter/select part of the left bar
    set left_navbar_html "
        <div class='filter-block'>
                <div class='filter-title'>
                   [::flyhh::mc Filter_Rooms "Filter Rooms"]
                </div>
                    $filter_html
              </div>
          <hr/>
    "
    
} else {
    set left_navbar_html ""
}