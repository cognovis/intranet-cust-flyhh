# ---------------------------------------------------------------
# 1. Page Contract
# ---------------------------------------------------------------

ad_page_contract { 

    
    @param order_by participants display order
    
    @author Neophytos Demetriou (neophytos@azet.sk)
    @creation-date 2014-10-15
    @last-modified 2014-10-30
    @cvs-id $Id$

} {
    project_id:integer,notnull
    { order_by "" }
    { room_p 0 }
    { international_p 0 }
    { overdue_p 0 }
    { notes_p 0 }
    { view_type "HTML" }
} -properties {
} -validate {

    check_event_exists -requires {project_id:integer} {

        ::flyhh::check_event_exists -project_id $project_id

    }

}

# 
#
set view_name "flyhh_event_participants_list"
set key "participant_id"
set bulk_actions {
    "Assign Room" "participant-room-assign" "Assign room for checked participants"
    "Assign Level" "participant-level-assign" "Assign level for checked participants"
    "Set to Confirmed" "participant-confirm" "Confirm checked participants"
    "Set to Cancelled" "participant-cancel" "Cancel checked participants"
    "Set to Waitlist" "participant-waitlist" "Put checked participants onto Waiting List"
    "Set to Checked-In" "participant-checked_in" "Mark checked participants as checked in"
    "Send Mail" "participant-email" "E-Mail checked participants"
}
set bulk_actions_form_id "flyhh_event_participants_form"
set return_url [export_vars -no_empty -base participants-list {project_id order_by}]

set locale [lang::user::locale]

# ---------------------------------------------------------------
# 2. Defaults & Security
# ---------------------------------------------------------------

# User id already verified by filters

set show_context_help_p 0
set notes ""
set filter_admin_html ""
set user_id [ad_maybe_redirect_for_registration]
set admin_p [im_is_user_site_wide_or_intranet_admin $user_id]
set subsite_id [ad_conn subsite_id]
set current_user_id $user_id
set today [lindex [split [ns_localsqltimestamp] " "] 0]
db_1row project_name "select project_type_id, project_name,event_id from im_projects p, flyhh_events e where p.project_id = :project_id and e.project_id = p.project_id"
set provider_id [im_company_internal]          ;# Company that provides this service - Us
set page_title "[_ intranet-cust-flyhh.List_of_participants]"
set context_bar [ad_context_bar [list [util_get_current_url] $project_name] $page_title]
set return_url [im_url_with_query]
set name_order [parameter::get -package_id [ad_conn package_id] -parameter "NameOrder" -default 1]

# Put security code in here.



# ---------------------------------------------------------------
# 3. Defined Table Fields
# ---------------------------------------------------------------

# Define the column headers and column contents that 
# we want to show:
#

set view_id [db_string get_view_id "select view_id from im_views where view_name=:view_name" -default 0]
if {!$view_id } {
    ad_return_complaint 1 "<b>Unknown View Name</b>:<br>
    The view '$view_name' is not defined. <br>
    Maybe you need to upgrade the database. <br>
    Please notify your system administrator."
    return
}

set column_headers [list]
set column_vars [list]
set column_headers_admin [list]
set extra_selects [list]
set extra_froms [list]
set extra_wheres [list]
set view_order_by_clause ""

if { $bulk_actions ne {} } {
    lappend column_headers "<input type=\"checkbox\">"
    lappend column_vars {[set _out_ "<input type=\"checkbox\" name=\"$key\" value=\"[set $key]\">"]}
    lappend column_headers_admin ""
}

set order_by_options [list [list "Sort Order" sort_order] [list Random random]]

set column_sql "
select
	vc.*
from
	im_view_columns vc
where
	view_id=:view_id
	and group_id is null
order by
	sort_order"

db_foreach column_list_sql $column_sql {

    set admin_html ""
    if {$admin_p} { 
        set url [export_vars -base "/intranet/admin/views/new-column" {column_id return_url}]
        set admin_html "<a href='$url'>[im_gif wrench ""]</a>" 
    }

    if {"" == $visible_for || [eval $visible_for]} {
        lappend column_headers "[lang::util::localize $column_name]"
        lappend column_vars "$column_render_tcl"
        lappend column_headers_admin $admin_html
        if {"" != $extra_select} { lappend extra_selects $extra_select }
        if {"" != $extra_from} { lappend extra_froms $extra_from }
        if {"" != $extra_where} { lappend extra_wheres $extra_where }
        if {"" != $order_by_clause} {
            set order_by_p([lang::util::localize $column_name]) 1
            if {$order_by==$column_name} {
                set view_order_by_clause $order_by_clause
            }
	    lappend order_by_options [list [lang::util::localize $column_name] $column_name]
        }
    }
}


# ---------------------------------------------------------------
# Filter with Dynamic Fields
# ---------------------------------------------------------------

set criteria [list]

set form_id "flyhh_event_participants_filter"
set action_url "participants-list"
set form_mode "edit"

ad_form \
    -name $form_id \
    -action $action_url \
    -mode $form_mode \
    -method GET \
    -export {project_id}\
    -form {

        {lead_p:text(select),optional
            {label {[::flyhh::mc Lead_or_follow "Lead/Follow"]}}
            {options {{"" ""} {Lead t} {Follow f}}}}
        {course:text(select),optional
            {label {[::flyhh::mc Course "Course"]}}
            {html {}}
            {options {[flyhh_material_options -project_id $project_id -material_type "Course Income" -locale $locale]}}
        }
        {bus_option:text(select),optional
            {label {[::flyhh::mc Bus "Bus"]}}
            {html {}}
            {options {[flyhh_material_options -project_id $project_id -material_type "Bus Options" -locale $locale]}}
        }
        {level:text(im_category_tree),optional
            {label {[::flyhh::mc Level "Level"]}} 
            {custom {category_type "Flyhh - Event Participant Level" translate_p 1 package_key "intranet-cust-flyhh"}}}

#        {validation_mask:text(multiselect),optional,multiple
#            {label {[::flyhh::mc Validation "Validation"]}} 
#            {options {
#                {"" ""} 
#                {"Invalid Partner" 1} 
#                {"Invalid Roommates" 2} 
#                {"Mismatch Accomm." 4} 
#                {"Mismatch L/F" 8}
#                {"Mismatch Level" 16}
#            }}} 

        {event_participant_status_id:text(im_category_tree),optional
            {label {[::flyhh::mc Status "Status"]}} 
            {custom {category_type "Flyhh - Event Registration Status" translate_p 1 package_key "intranet-cust-flyhh"}}}

        {room_p:text(select),optional
            {label {[::flyhh::mc room_p "Room Assigned"]}}
            {options {{No 0} {"No w/o external" 3} {Yes 1} {"Yes w/ external" 2} {"Wrong Type" 4}}}
        }
        {international_p:text(select),optional
            {label {[::flyhh::mc international_p "International?"]}}
            {options {{No 0} {Yes 1}}}
        }
	{notes_p:text(select),optional
            {label {[::flyhh::mc notes_p "Notes?"]}}
            {options {{No 0} {Yes 1}}}
        }
        {overdue_p:text(select),optional
            {label {[::flyhh::mc overdue_p "Overdue?"]}}
            {options {{No 0} {Yes 1}}}
        }
        {order_by:text(select),optional
            {label {[::flyhh::mc Order_by "Order by"]}}
            {options $order_by_options}
	}
    } -on_submit {

        set mask 0
#        foreach num $validation_mask {
#            if { $num == 1 } { lappend criteria "invalid_partner_p" }
#            if { $num == 2 } { lappend criteria "invalid_roommates_p" }
#            if { $num == 4 } { lappend criteria "mismatch_accomm_p" }
#            if { $num == 8 } { lappend criteria "mismatch_lead_p" }
#            if { $num == 16 } { lappend criteria "mismatch_level_p" }
#        }

        foreach varname {lead_p course bus_option event_participant_status_id validation_status_id} {

            if { [exists_and_not_null $varname] } {

                set value [set $varname]
                set quoted_value [ns_dbquotevalue $value]

                if { $varname eq {validation_status_id} && ( $value eq {82513} || $value eq {82514} ) } {

                        # if filtering participants by those who lack partner (82513 - Invalid Partner)
                        # or roommates (82514 - Invalid Roommates) then include participants that lack
                        # both (82512 - Invalid Both).

                        lappend criteria "($varname = $quoted_value OR $varname = '82512')"

                } else {

                    lappend criteria "$varname = $quoted_value" 

                }

            }

        }

    }

# ---------------------------------------------------------------
# Support for exporting table to excel
# ---------------------------------------------------------------

# List to store the view_type_options
set view_type_options [list [list HTML ""]]
set view_type_options [concat $view_type_options [list [list Excel xls]] [list [list Openoffice ods]] [list [list PDF pdf]]]

ad_form -extend -name $form_id -form {
    {view_type:text(select),optional {label "#intranet-openoffice.View_type#"} {options $view_type_options}}
}

# Create a ns_set with all local variables in order
# to pass it to the SQL query
set form_vars [ns_set create]
foreach varname [info locals] {

    # Don't consider variables that start with a "_", that
    # contain a ":" or that are array variables:
    if {"_" == [string range $varname 0 0]} { continue }
    if {[regexp {:} $varname]} { continue }
    if {[array exists $varname]} { continue }

    # Get the value of the variable and add to the form_vars set
    if {[set $varname] eq ""} {
	set value ""
    } else {
	set value [expr "\$$varname"]
    }
    ns_set put $form_vars $varname $value
}

# ---------------------------------------------------------------
# 5. Generate SQL Query
# ---------------------------------------------------------------

if {$room_p} {
    switch $room_p {
	2 {lappend criteria "(er.room_id is not null or ep.accommodation = (select material_id from im_materials where material_nr = 'external_accommodation'))"}
	3 {lappend criteria "(er.room_id is null and ep.accommodation <> (select material_id from im_materials where material_nr = 'external_accommodation'))"}
	4 {lappend criteria "(er.room_material_id != ep.accommodation)"}
        default {lappend criteria "er.room_id is not null"}
    }
}

if {$international_p} {
    lappend criteria "ha_country_code != 'de'"
}

# Find out if the participant has provided a note
if {$notes_p} {
    lappend criteria "(select count(*) from im_notes where object_id = ep.participant_id) >0"
    lappend extra_selects "(select array_agg(note) from im_notes where object_id = ep.participant_id) as notes"
}

# Find out if the participant is overdue
if {$overdue_p} {
    lappend criteria "(select coalesce(now()::date - effective_date::date,null) from flyhh_event_participants f, im_costs c where event_participant_status_id = [flyhh::status::pending_payment] and c.cost_id = f.invoice_id and f.participant_id = ep.participant_id) > 14 and event_participant_status_id = [flyhh::status::pending_payment]"
}


if {$view_order_by_clause != ""} {
    set order_by_clause "order by $view_order_by_clause"
} else {
    set order_by_clause "order by sort_order"
}

# Support for randomization
if {$order_by == "random"} {
    set order_by_clause "order by random()"
}

if {$order_by == "sort_order"} {
    set order_by_clause "order by sort_order"
}

set extra_where_clause [join [concat $criteria $extra_wheres] " and "]
if { $extra_where_clause ne {} } {
    set extra_where_clause "and $extra_where_clause"
}

set extra_select [join $extra_selects ","]
if { ![empty_string_p $extra_select] } {
    set extra_select ",$extra_select"
}

set extra_from [join $extra_froms ","]
if { ![empty_string_p $extra_from] } {
    set extra_from ",$extra_from"
}

set sql "
    select 
    (select coalesce(now()::date - effective_date::date,null) from flyhh_event_participants f, im_costs c where event_participant_status_id = [flyhh::status::confirmed] and c.cost_id = f.quote_id and f.participant_id = ep.participant_id) as days_since_confirmation,
    (select coalesce(now()::date - effective_date::date,null) from flyhh_event_participants f, im_costs c where event_participant_status_id = [flyhh::status::pending_payment] and c.cost_id = f.invoice_id and f.participant_id = ep.participant_id) as days_since_invoice,
    ep.*,er.*,uc.ha_country_code,uc.ha_city,
        person__name(partner_person_id) as partner_person_name, 
        partner_person_id,
        party__email(ep.person_id) as email,
        (select effective_date::date from im_costs where cost_id = quote_id) as confirmation_date,
        (select effective_date::date from im_costs where cost_id = invoice_id) as accepted_date,
        (select round(sum(item_units*price_per_unit)) from im_costs c, im_invoice_items ii, im_materials m where ii.item_material_id = m.material_id and ii.project_id = :project_id and ii.invoice_id = c.cost_id and c.customer_id = ep.company_id and m.material_type_id in (9004)) as course_amount,
        (select round(sum(item_units*price_per_unit)) from im_costs c, im_invoice_items ii, im_materials m where ii.item_material_id = m.material_id and ii.project_id = :project_id and ii.invoice_id = c.cost_id and c.customer_id = ep.company_id and m.material_type_id in (9006)) as discount_amount,
        (select round(sum(item_units*price_per_unit)) from im_costs c, im_invoice_items ii, im_materials m where ii.item_material_id = m.material_id and ii.project_id = :project_id and ii.invoice_id = c.cost_id and c.customer_id = ep.company_id and m.material_type_id in (9002)) as accommodation_amount,
        (select round(sum(item_units*price_per_unit)) from im_costs c, im_invoice_items ii, im_materials m where ii.item_material_id = m.material_id and ii.project_id = :project_id and ii.invoice_id = c.cost_id and c.customer_id = ep.company_id and m.material_type_id in (9007)) as food_amount
        $extra_select 
    from flyhh_event_participants ep
    left outer join (select ro.person_id, room_name, ro.room_id, r.room_material_id, office_name from flyhh_event_rooms r, im_offices o, flyhh_event_room_occupants ro where ro.room_id = r.room_id and ro.project_id = :project_id and r.room_office_id = o.office_id) er on (er.person_id = ep.person_id),
   users_contact uc
    $extra_from
    where project_id=:project_id
    and uc.user_id = ep.person_id
    $extra_where_clause
    $order_by_clause
"

# ---------------------------------------------------------------
# 6. Format the Filter
# ---------------------------------------------------------------

# Note that we use a nested table because im_slider might
# return a table with a form in it (if there are too many
# options


# ----------------------------------------------------------
# Do we have to show administration links?

set admin_html "<ul>"

# Append user-defined menus
set bind_vars [list return_url $return_url]
append admin_html [im_menu_ul_list -no_uls 1 "participants_admin" $bind_vars]
append admin_html "</ul>"

# ---------------------------------------------------------------
# 7. Format the List Table Header
# ---------------------------------------------------------------

# Set up colspan to be the number of headers + 1 for the # column
set colspan [expr [llength $column_headers] + 1]

set table_header_html ""

# Format the header names with links that modify the
# sort order of the SQL query.
#
set url "participants-list?"
set query_string [export_ns_set_vars url [list order_by]]
if { ![empty_string_p $query_string] } {
    append url "$query_string&"
}

append table_header_html "<tr>\n"
set ctr 0
foreach col $column_headers {
    set wrench_html [lindex $column_headers_admin $ctr]
    regsub -all " " $col "_" col_txt
    set col_txt [::flyhh::mc $col_txt $col]
    if {[info exists order_by_p($col)]} {
        append table_header_html "<td class=rowtitle><a href=\"${url}order_by=[ns_urlencode $col]\">$col_txt</a>$wrench_html</td>\n"
    } else {
        append table_header_html "<td class=rowtitle>$col_txt $wrench_html</td>\n"
    }
    incr ctr
}
append table_header_html "</tr>\n"

# ---------------------------------------------------------------
# Create Material Price Array
# ---------------------------------------------------------------

db_foreach price_array {
    select round(price) as price_per_unit, im.material_id
    from im_materials im inner join im_timesheet_prices itp on (itp.material_id=im.material_id)
    where company_id = :provider_id
    and itp.task_type_id = :project_type_id
} {
    set material_price($material_id) $price_per_unit
}

# ---------------------------------------------------------------
# 8. Format the Result Data
# ---------------------------------------------------------------

set table_body_html ""
set bgcolor(0) " class=roweven "
set bgcolor(1) " class=rowodd "
set ctr 0

if { $bulk_actions ne {} } {
    append table_body_html "<form id=\"${bulk_actions_form_id}\" action=\"participants-bulk\" method=\"post\">"
    append table_body_html "<input type=hidden name=\"project_id\" value=\"${project_id}\">"
    append table_body_html "<input type=hidden name=\"return_url\" value=\"${return_url}\">"
}
if {[lsearch [list xls pdf ods] $view_type] > -1} {
    intranet_openoffice::spreadsheet -view_name $view_name -sql $sql -output_filename "participant-list.$view_type" -table_name "$page_title" -variable_set $form_vars
        ad_script_abort
}

db_foreach event_participants_query $sql {

    set participant_status_pretty [im_category_from_id  $event_participant_status_id]

    if {$room_id ne ""} {
        set room_url [export_vars -base "/flyhh/admin/room-one" -url {{room_id $room_id} {filter_project_id $project_id}}]
        set room_html "<a href='$room_url'>[flyhh_event_room_description -room_id $room_id]</a>"
    } else {
        set room_html ""
    }
    if {$partner_participant_id ne ""} {
        set partner_url [export_vars -base "registration" -url {{ project_id $project_id } { participant_id $partner_participant_id }}]
        if {$partner_mutual_p} {
            set style_html "style=color:green;"
            set mutual_html ""
        } else {
            set style_html "style=color:orange;"
            set mutual_html "<br />(not mutual)"
        }
        set partner_html "<a $style_html href='$partner_url'>$partner_person_name</a>$mutual_html"
        if {$partner_email eq ""} {
            append partner_html "<br />(match by name)"
        }
    } else {
        if {$partner_text ne ""} {
            set partner_html  "<font color=red>$partner_text</font><br />(not registered)"
        } else {
            set partner_html ""
        }
    }

    # ---------------------------------------------------------------
    # Check the finances
    # ---------------------------------------------------------------
    if {$course_amount ne $material_price($course)} {
	if {$course_amount < $material_price($course)} {
	    set font "red"
	} else {
	    set font "green"
	}
	set course_amount "<font color='$font'>$course_amount -- $material_price($course)</font>"
    }
    if {$accommodation_amount ne $material_price($accommodation)} {
	if {$accommodation_amount < $material_price($accommodation)} {
	    set font "red"
	} else {
	    set font "green"
	}
	set accommodation_amount "<font color='$font'>$accommodation_amount -- $material_price($accommodation)</font>"
    }
    if {$food_amount ne $material_price($food_choice)} {
	if {$food_amount < $material_price($food_choice)} {
	    set font "red"
	} else {
	    set font "green"
	}
	set food_amount "<font color='$font'>$food_amount -- $material_price($food_choice)</font>"
    }

    if {$discount_amount ne "" && $partner_html eq ""} {
	set discount_amount "<font color='red'>$discount_amount</font>"
    }

    # Resolve the alternative accommodation into a string
    set alterantive_accommodation_html ""
    if {[llength $alternative_accommodation]>0} {
        append alterantive_accommodation_html "<ul>"
        foreach accommodation_material_id $alternative_accommodation {
            append alterantive_accommodation_html "<li>[im_material_name -material_id $accommodation_material_id]</li>"
        }
        append alterantive_accommodation_html "</ul>"
    }

    # Format the days since
    if {$event_participant_status_id == [flyhh::status::confirmed]} {
	set days_since_html "$days_since_confirmation"
    } else {
	set days_since_html ""
    }

    if {$days_since_confirmation > 14 && $event_participant_status_id == [flyhh::status::confirmed]} {
	set days_since_html "<font color=orange>$days_since_confirmation</font>"
    }
    if {$days_since_confirmation > 28 && $event_participant_status_id == [flyhh::status::confirmed]} {
	set days_since_html "<font color=red>$days_since_confirmation</font>"
    }

    if {$days_since_invoice > 28 && $event_participant_status_id == [flyhh::status::pending_payment]} {
	append days_since_html "<font color=red>$days_since_invoice </font>"
    } elseif {$days_since_invoice > 14  && $event_participant_status_id == [flyhh::status::pending_payment]} {
	append days_since_html "<font color=orange>$days_since_invoice </font>"
    } elseif {$event_participant_status_id == [flyhh::status::pending_payment]} {
	append days_since_html "$days_since_invoice"
    }

    # Append together a line of data based on the "column_vars" parameter list
    set row_html "<tr$bgcolor([expr $ctr % 2])>\n"
    foreach column_var $column_vars {
        append row_html "\t<td valign=top>"
        set cmd "append row_html $column_var"
        if [catch {
            eval "$cmd"
        } errmsg] {
            # TODO: warn user
        }
        append row_html "</td>\n"
    }
    append row_html "</tr>\n"
    append table_body_html $row_html
    
    incr ctr
}

# Show a reasonable message when there are no result rows:
if { [empty_string_p $table_body_html] } {
    set table_body_html "
        <tr><td colspan=$colspan><ul><li><b> 
No users        </b></ul></td></tr>"
}

if { $bulk_actions ne {} } {

    set row_html "<tr><td colspan=$colspan><select name=\"bulk_action\">"
    foreach {label url title} $bulk_actions {
        # set row_html "<tr><td colspan=$colspan><button type=\"submit\" title=\"${title}\" onmousedown=\"document.getElementById('${bulk_actions_form_id}').action = '${url}';\">${label}</button></td></tr>"
        append row_html "<option title=\"${title}\" name=\"bulk_action\">${label}</option>"
    }
    append row_html "</select>" "<button type=\"submit\">Update</button>" "</td></tr>"
    append table_body_html $row_html
    append table_body_html "</form>"

}

# ---------------------------------------------------------------
# Navbars
# ---------------------------------------------------------------

# Get the URL variables for pass-though
set query_pieces [split [ns_conn query] "&"]
set pass_through_vars [list]
foreach query_piece $query_pieces {
    if {[regexp {^([^=]+)=(.+)$} $query_piece match var val]} {
	# exclude "form:...", "__varname" and "letter" variables
	if {[regexp {^form} $var match]} {continue}
	if {[regexp {^__} $var match]} {continue}
	if {[regexp {^letter$} $var match]} {continue}
	set var [ns_urldecode $var]
	lappend pass_through_vars $var
    }
}


# Compile and execute the formtemplate if advanced filtering is enabled.
eval [template::adp_compile -string {<formtemplate id="$form_id" style="tiny-plain-po"></formtemplate>}]
set filter_html $__adp_output

# Left Navbar is the filter/select part of the left bar
set left_navbar_html "
	<div class='filter-block'>
        	<div class='filter-title'>
	           #intranet-cust-flyhh.Filter_Participants# $filter_admin_html
        	</div>
            	$filter_html
      	</div>
      <hr/>
"
