ad_page_contract {

    @author malte.sussdorff@cognovis.de
    @creation-date 2015-03-11
    @last-modified 2015-03-11

    Display the list of rooms available in the system
    
} {
    project_id:integer,optional
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
        sleeping_spots {
            label {[::flyhh::mc room_sleeping_spots "Sleeping Spots"]}
        }
        single_beds {
            label {[::flyhh::mc room_single_beds "Single Beds"]}
        }
        double_beds {
            label {[::flyhh::mc room_double_beds "Double Beds"]}
        }
        additional_beds {
            label {[::flyhh::mc room_additional_beds "Additional Beds"]}
        }
        toilet_p {
            label {[::flyhh::mc room_toilet "Toilet ?"]}
            display_template {
                <if @rooms.toilet_p@ eq f><font color="red">No</font></if>
                <else>Yes</else>
            }
        }
        bath_p {
            label {[::flyhh::mc room_toilet "Toilet ?"]}
            display_template {
                <if @rooms.bath_p@ eq f><font color="red">No</font></if>
                <else>Yes</else>
            }
        }
        description {
            label {[::flyhh::mc room_description "Description"]}
            display_template {
                @rooms.description;noquote@
            }
        }
    }
    

db_multirow -extend {room_url} rooms $multirow "select *,im_name_from_id(room_material_id) as room_type from flyhh_event_rooms" {
    # Change the sleeping spots if we have a project
    set room_url [export_vars -base "/flyhh/admin/room-one" -url {room_id}]
    set description [template::util::richtext::get_property html_value $description]
}

set return_url [ad_return_url] 
# Filter (possibly) later on
set left_navbar_html ""