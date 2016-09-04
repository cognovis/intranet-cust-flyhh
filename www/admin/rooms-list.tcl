ad_page_contract {

    @author malte.sussdorff@cognovis.de
    @creation-date 2015-03-11
    @last-modified 2015-03-11

    Display the list of rooms available in the system
    
} {
    {filter_project_id ""}
    {participant_filter "all"}
    room_material_id:integer,optional
    room_office_id:integer,optional
    {orderby ""}
}

set show_context_help_p 0
set filter_admin_html ""
set page_title "[::flyhh::mc Rooms "Rooms"]"
set context_bar [ad_context_bar $page_title]

set list_id "rooms_list"
set multirow "rooms"

template::list::create \
    -name rooms_list \
    -multirow $multirow \
    -elements {
        room_name {
            label {[::flyhh::mc room_Name "Name"]}
            link_url_col room_url
	    orderby room_name
        }
        room_type {
            label {[::flyhh::mc room_type "Room Type"]}
            display_template {
                @rooms.room_type;noquote@
            }
            orderby_asc {room_type asc, room_name asc}
            orderby_desc {room_type desc, room_name asc}
        }
        room_location {
            label {[::flyhh::mc room_location "Room Location"]}
            display_template {
                @rooms.room_location;noquote@
            }
            orderby_asc {room_location asc, room_type asc, room_name asc}
            orderby_desc {room_location desc, room_type asc,room_name asc}
        }
        sleeping_spots {
            label {[::flyhh::mc room_sleeping_spots "Sleeping Spots"]}
            html {style "text-align:center;"}
            display_template {
                @rooms.sleeping_spots;noquote@
            }
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
                <if @rooms.toilet_p@ ne t><font color="red">No</font></if>
                <else>Yes</else>
            }
            html {style "text-align:center;"}
        }
        bath_p {
            label {[::flyhh::mc room_bath "Bath ?"]}
            display_template {
                <if @rooms.bath_p@ ne t><font color="red">No</font></if>
                <else>Yes</else>
            }
            html {style "text-align:center;"}
        }
        occupants {
            label {[::flyhh::mc Occupants "Occupants"]}
            display_template {
                @rooms.occupants;noquote@
            }
        }
        description {
            label {[::flyhh::mc room_description "Description"]}
            display_template {
                @rooms.description;noquote@
            }
        }
	delete {
	    label {[::flyhh::mc room_delete "Delete Room"]}
	    display_template {
		<if @rooms.delete_url@ ne "">
		<a href='@rooms.delete_url;noquote@'>[_ intranet-cust-flyhh.room_delete]</a>
		</if>
	    }
	}
    } \
    -orderby {
	default_value room_name asc
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

set event_options [list [list "" ""]]
db_foreach events "
    select p.project_id,project_name 
    from im_projects p, flyhh_events e 
    where project_status_id = [im_project_status_open] 
    and p.project_id = e.project_id
" {
    lappend event_options [list $project_name $project_id]
}


set extra_where_clause ""
set occ_extra_where_clause ""
ad_form \
    -name $form_id \
    -action $action_url \
    -mode $form_mode \
    -method GET \
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
        {filter_project_id:text(select),optional
            {label {[::flyhh::mc Event "Event"]}}
            {html {}}
            {options {$event_options}}
            {value $filter_project_id}
        }
        {participant_filter:text(select),optional
            {label {[::flyhh::mc Participant "Participant"]}}
            {html {}}
            {options {{"Yes" "t"} {"No" "f"} {"All" "all"}}}
            {value $participant_filter}
        }
    } -on_submit {

        foreach varname {room_office_id room_material_id } {

            if { [exists_and_not_null $varname] } {

                set value [set $varname]
                set quoted_value [ns_dbquotevalue $value]
                append extra_where_clause "and $varname = $quoted_value" 

            }

        }

	switch $participant_filter {
	    "t" {
		append occ_extra_where_clause "and participant_id is not null" 
	    }
	    "f" {
		append occ_extra_where_clause "and participant_id is null" 
	    }
            default {
		# Show all
            }
	}

    }

if {$filter_project_id ne ""} {
    set sql "select *,material_name as room_type, im_name_from_id(room_office_id) as room_location,
    (select count(*) from flyhh_event_room_occupants ro where ro.room_id = er.room_id and ro.project_id = :filter_project_id) as taken_spots
    from flyhh_event_rooms er, im_materials m where m.material_id = er.room_material_id $extra_where_clause [template::list::orderby_clause -orderby -name "rooms_list"]"
} else {
    set sql "select *,material_name as room_type, im_name_from_id(room_office_id) as room_location, 0 as taken_spots from flyhh_event_rooms ro,im_materials m where m.material_id = ro.room_material_id $extra_where_clause [template::list::orderby_clause -orderby -name "rooms_list"]"
}

db_multirow -extend {room_url delete_url occupants} rooms $multirow $sql {
    # Change the sleeping spots if we have a project
    set room_url [export_vars -base "/flyhh/admin/room-one" -url {room_id filter_project_id}]
    set delete_url ""
    if {![db_string used "select 1 from flyhh_event_room_occupants where room_id = :room_id limit 1" -default 0]} {
	set delete_url [export_vars -base "room-delete" -url {room_id {return_url [util_get_current_url]}}]
    } 
    set description [template::util::richtext::get_property html_value $description]
    if {$taken_spots >0} {
        set remaining_spots [expr $sleeping_spots - $taken_spots]
        if {$remaining_spots >0} {
            set sleeping_spots "<font color='green'>$remaining_spots</font> / $sleeping_spots"
        } else {
            set sleeping_spots "<font color='red'>$remaining_spots</font> / $sleeping_spots"
            set room_type "<strike>$room_type</strike>"   
            set room_location "<strike>$room_location</strike>"   
        }
    }
    set occupants [list]    
    if {$filter_project_id ne ""} {
        # Set the occupants
        db_foreach occupant "select im_name_from_id(ro.person_id) as occupant_name, ro.person_id,ep.participant_id from flyhh_event_room_occupants ro left outer join flyhh_event_participants ep on (ep.project_id = ro.project_id and ep.person_id = ro.person_id)
        where ro.room_id = :room_id and ro.project_id = :filter_project_id $occ_extra_where_clause
        order by im_name_from_id(ro.person_id)" {

                set company_id [db_string company_id "select company_id from im_companies where primary_contact_id =:person_id order by company_id desc limit 1" -default ""]
                if {$company_id eq ""} {
                    set occupant_url [export_vars -base "/intranet/users/view" -url {{user_id $person_id}}]            
                } {
                    set occupant_url [export_vars -base "/intranet/companies/view" -url {company_id}]            
                }
            set occupant "<a href='$occupant_url'>$occupant_name</a>"
            if {$participant_id ne ""} {
                set registration_url [export_vars -base "/flyhh/admin/registration" -url {participant_id project_id}]
		append occupant " (<a href='$registration_url'>$participant_id</a>)"
            }
	    lappend occupants $occupant
        }
    }
    if {$occupants ne ""} {
        set occupants "<ul><li>[join $occupants "</li><li>"]</li></ul>"
    }
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
