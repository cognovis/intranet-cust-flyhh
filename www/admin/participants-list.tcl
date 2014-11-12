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
} -properties {
} -validate {

    event_exists_ck -requires {project_id:integer} {

        set sql "select 1 from flyhh_events where project_id=:project_id limit 1"
        set is_event_proj_p [db_string check_event_project $sql -default 0]
        if { !$is_event_proj_p } {
            ad_complain "no event found for the given project_id (=$project_id)"
        }

    }

}

# 
#
set view_name "flyhh_event_participants_list"
set key "participant_id"
set bulk_actions {
    "Set to Confirmed" "participant-confirm" "Confirm checked participants"
    "Set to Cancelled" "participant-cancel" "Cancel checked participants"
}
set bulk_actions_form_id "flyhh_event_participants_form"
set return_url [export_vars -no_empty -base participants-list {project_id order_by}]


# ---------------------------------------------------------------
# 2. Defaults & Security
# ---------------------------------------------------------------

# User id already verified by filters

set show_context_help_p 0
set filter_admin_html ""
set user_id [ad_maybe_redirect_for_registration]
set admin_p [im_is_user_site_wide_or_intranet_admin $user_id]
set subsite_id [ad_conn subsite_id]
set current_user_id $user_id
set today [lindex [split [ns_localsqltimestamp] " "] 0]
set page_title "[_ intranet-cust-flyhh.List_of_participants]"
set context_bar [ad_context_bar $page_title]
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
    -export {project_id order_by}\
    -form {

        {lead_p:text(select),optional
            {label {[::flyhh::mc Lead_or_follow "Lead/Follow"]}}
            {options {{"" ""} {Lead t} {Follow f}}}}

        {level:text(im_category_tree),optional
            {label {[::flyhh::mc Level "Level"]}} 
            {custom {category_type "Flyhh - Event Participant Level" translate_p 1 package_key "intranet-cust-flyhh"}}}

        {validation_mask:text(multiselect),optional,multiple
            {label {[::flyhh::mc Validation "Validation"]}} 
            {options {
                {"" ""} 
                {"Invalid Partner" 1} 
                {"Invalid Roommates" 2} 
                {"Mismatch Accomm." 4} 
                {"Mismatch L/F" 8}
                {"Mismatch Level" 16}
            }}} 

        {event_participant_status_id:text(im_category_tree),optional
            {label {[::flyhh::mc Status "Status"]}} 
            {custom {category_type "Flyhh - Event Registration Status" translate_p 1 package_key "intranet-cust-flyhh"}}}

    } -on_submit {

        set mask 0
        foreach num $validation_mask {
            if { $num == 1 } { lappend criteria "invalid_partner_p" }
            if { $num == 2 } { lappend criteria "invalid_roommates_p" }
            if { $num == 4 } { lappend criteria "mismatch_accomm_p" }
            if { $num == 8 } { lappend criteria "mismatch_lead_p" }
            if { $num == 16 } { lappend criteria "mismatch_level_p" }
        }

        foreach varname {lead_p level event_participant_status_id validation_status_id} {

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
# 5. Generate SQL Query
# ---------------------------------------------------------------


if {$view_order_by_clause != ""} {
    set order_by_clause "order by $view_order_by_clause"
} else {
    set order_by_clause "order by participant_id"
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
    select *, 
        person__name(partner_person_id) as partner_person_name, 
        party__email(person_id) as email
        $extra_select 
    from flyhh_event_participants ep 
    $extra_from
    where project_id=:project_id
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
# 8. Format the Result Data
# ---------------------------------------------------------------

set table_body_html ""
set bgcolor(0) " class=roweven "
set bgcolor(1) " class=rowodd "
set ctr 0

if { $bulk_actions ne {} } {
    append table_body_html "<form id=\"${bulk_actions_form_id}\" action=\"participants-bulk\" method=\"post\">"
    append table_body_html "<input type=hidden name=\"return_url\" value=\"${return_url}\">"
}

db_foreach event_participants_query $sql {


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
