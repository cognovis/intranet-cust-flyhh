ad_page_contract {

    @author malte.sussdorff@cognovis.de
    @creation-date 2015-03-11
    @last-modified 2015-03-11

    Display the list of rooms available in the system
    
} {
    project_id:integer,optional
    room_material_id:integer,optional
    room_office_id:integer,optional
}

set show_context_help_p 0
set filter_admin_html ""
set page_title "[::flyhh::mc Rooms "Rooms"]"
set context_bar [ad_context_bar $page_title]

set list_id "rooms_list"
set multirow "rooms"

template::list::create \
    -name $list_id \
    -multirow $multirow \
    -elements {
        room_name {
            label {[::flyhh::mc room_Name "Name"]}
            display_template {
                <a href='@rooms.room_url;noquote@'>@rooms.room_name;noquote@</a>
            }
        }
        room_type {
            label {[::flyhh::mc room_type "Room Type"]}
            html {style "text-align:center;"}
        }
        room_location {
            label {[::flyhh::mc room_location "Room Location"]}
            html {style "text-align:center;"}
        }
        sleeping_spots {
            label {[::flyhh::mc room_sleeping_spots "Sleeping Spots"]}
            html {style "text-align:center;"}
        }
        single_beds {
            label {[::flyhh::mc room_single_beds "Single Beds"]}
            html {style "text-align:center;"}
        }
        double_beds {
            label {[::flyhh::mc room_double_beds "Double Beds"]}
            html {style "text-align:center;"}
        }
        additional_beds {
            label {[::flyhh::mc room_additional_beds "Additional Beds"]}
            html {style "text-align:center;"}
        }
        toilet_p {
            label {[::flyhh::mc room_toilet "Toilet ?"]}
            display_template {
                <if @rooms.toilet_p@ eq f><font color="red">No</font></if>
                <else>Yes</else>
            }
            html {style "text-align:center;"}
        }
        bath_p {
            label {[::flyhh::mc room_bath "Bath ?"]}
            display_template {
                <if @rooms.bath_p@ eq f><font color="red">No</font></if>
                <else>Yes</else>
            }
            html {style "text-align:center;"}
        }
        description {
            label {[::flyhh::mc room_description "Description"]}
            display_template {
                @rooms.description;noquote@
            }
        }
    }

# ---------------------------------------------------------------
# Filter with Dynamic Fields
# ---------------------------------------------------------------

set criteria [list]

set form_id "flyhh_event_rooms_filter"
set action_url "rooms-list"
set form_mode "edit"

set material_options [list [list "" ""]]

db_foreach materials {
    SELECT m.material_id,material_name
    FROM im_materials m 
    WHERE m.material_type_id=(SELECT material_type_id FROM im_material_types WHERE material_type='Accommodation')
    and material_status_id = 9100
} {
    lappend material_options [list $material_name $material_id]
}

set office_options [list [list "" ""]]

db_foreach materials {
    SELECT office_id,office_name
    FROM im_offices o
    WHERE office_type_id = 175;
} {
    lappend office_options [list $office_name $office_id]
}

set extra_where_clause ""
ad_form \
    -name $form_id \
    -action $action_url \
    -mode $form_mode \
    -method GET \
    -export {project_id}\
    -form {
        {room_material_id:text(select),optional
            {label {[::flyhh::mc room_type "Room Type"]}}
            {html {}}
            {options {$material_options}}
        }
        {room_office_id:text(select),optional
            {label {[::flyhh::mc room_location "Room Location"]}}
            {html {}}
            {options {$office_options}}
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

set sql "select *,im_name_from_id(room_material_id) as room_type, im_name_from_id(room_office_id) as room_location from flyhh_event_rooms where 1=1 $extra_where_clause"

db_multirow -extend {room_url} rooms $multirow $sql {
    # Change the sleeping spots if we have a project
    set room_url [export_vars -base "/flyhh/admin/room-one" -url {room_id}]
    set description [template::util::richtext::get_property html_value $description]
}

# Filter (possibly) later on
# Compile and execute the formtemplate if advanced filtering is enabled.
eval [template::adp_compile -string {<formtemplate id="$form_id" style="tiny-plain-po"></formtemplate>}]
set filter_html $__adp_output

# Left Navbar is the filter/select part of the left bar
set left_navbar_html "
    <div class='filter-block'>
            <div class='filter-title'>
               [::flyhh::mc Filter_Rooms "Filter Rooms"]
               $filter_admin_html
            </div>
                $filter_html
          </div>
      <hr/>
"
