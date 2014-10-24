# ---------------------------------------------------------------
# 1. Page Contract
# ---------------------------------------------------------------

ad_page_contract { 

    

} {
    { order_by "" }
}

# absence_type_id
#
set view_name "event_participants_list"
set view_type ""
set department_id ""

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
set context_bar [im_context_bar $page_title]
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


set project_type_list [list]


# ---------------------------------------------------------------
# Filter with Dynamic Fields
# ---------------------------------------------------------------

set form_id "event_participants_filter"
set action_url "../registration"
set form_mode "edit"

ad_form \
    -name $form_id \
    -action $action_url \
    -mode $form_mode \
    -method GET \
    -export {order_by}\
    -form {
        {project_type_id:text(select) {label "[_ intranet-cust-flyhh.Project_Type]"} {options $project_type_list }}
    }


# List to store the view_type_options
set view_type_options [list [list HTML ""]]

# Run callback to extend the filter and/or add items to the view_type_options
#callback im_projects_index_filter -form_id $form_id
#ad_form -extend -name $form_id -form {
#    {view_type:text(select),optional {label "#intranet-openoffice.View_type#"} {options $view_type_options}}
#}

# ---------------------------------------------------------------
# 5. Generate SQL Query
# ---------------------------------------------------------------

set criteria [list]

# If the user isn't HR, we can only see employees where the current user is the supervisor
# if {![im_user_is_hr_p $user_id]} {
    # Only HR can view all users, everyone only the users he is supervising
#    lappend extra_wheres "employee_id in (select employee_id from im_employees where supervisor_id = :user_id)"
# }


if {$view_order_by_clause != ""} {
    set order_by_clause "order by $view_order_by_clause"
} else {
    set order_by_clause "order by participant_id"
}

set where_clause [join $criteria " and "]
if { ![empty_string_p $where_clause] } {
    set where_clause " and $where_clause"
}

set extra_select [join $extra_selects ","]
if { ![empty_string_p $extra_select] } {
    set extra_select ",$extra_select"
}

set extra_from [join $extra_froms ","]
if { ![empty_string_p $extra_from] } {
    set extra_from ",$extra_from"
}

set extra_where [join $extra_wheres " and "]
if { ![empty_string_p $extra_where] } {
    set extra_where " and $extra_where"
}

# Get a table with
# - Username (from the owner of the absence /leave entitlement)
# - Department of the owner
# - Vacation already taken (in the current year)
# - Vacation days left (in the current year)
# - Vacation approved yet coming up this year
# Grouping should be by vacation type
# Ordering should be by default by the owner


#set booking_year [string range $reference_date 0 3]
#set eoy "${booking_year}-12-31"
#set soy "${booking_year}-01-01"


# Fill Has values for each employee that is visible
#set active_category_ids [template::util::tcl_to_sql_list [im_sub_categories [im_user_absence_status_active]]]
#set requested_category_ids [template::util::tcl_to_sql_list [im_sub_categories [im_user_absence_status_requested]]]
set sql "
    select *
       $extra_select 
    from im_event_participants ep 
    inner join parties pa on (pa.party_id=ep.person_id) 
    inner join persons p on (p.person_id=ep.person_id)
    $extra_where
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

ns_log Notice "/intranet-cust-flyhh/admin/participants-list: Before admin links"
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
    set col_txt [lang::message::lookup "" intranet-core.$col_txt $col]
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

# callback im_projects_index_before_render -view_name $view_name \
#    -view_type $view_type -sql $selection -table_header $page_title -variable_set $form_vars

db_foreach event_participants_query $sql {


    set default $event_participant_status_id

    set select_name "event_participant.$participant_id"

    set status_select [im_category_select "Intranet Company Status" $select_name $default]

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
	           #intranet-cust-flyhh.Filter_Projects# $filter_admin_html
        	</div>
            	$filter_html
      	</div>
      <hr/>
"
