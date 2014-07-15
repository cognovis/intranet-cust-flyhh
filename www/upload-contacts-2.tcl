# /packages/intranet-core/www/companies/upload-contacts-2.tcl
#
# Copyright (C) 1998-2004 various parties
# The code is based on ArsDigita ACS 3.4
#
# This program is free software. You can redistribute it
# and/or modify it under the terms of the GNU General
# Public License as published by the Free Software Foundation;
# either version 2 of the License, or (at your option)
# any later version. This program is distributed in the
# hope that it will be useful, but WITHOUT ANY WARRANTY;
# without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.

# ---------------------------------------------------------------
# Page Contract
# ---------------------------------------------------------------


ad_page_contract {
    /intranet/companies/upload-contacts-2.tcl
    Read a .csv-file with header titles exactly matching
    the data model and insert the data into "users" and
    "acs_rels".

    @author various@arsdigita.com
    @author frank.bergmann@project-open.com

    @param transformation_key Determins a number of additional fields 
	   to import
    @param create_dummy_email Set this for example to "@nowhere.com" 
	   in order to create dummy emails for users without email.

} {
    return_url
    upload_file
    { transformation_key "" }
    { create_dummy_email "" }
    cost_center_id
} 


# ---------------------------------------------------------------
# Security & Defaults
# ---------------------------------------------------------------

set current_user_id [ad_maybe_redirect_for_registration]
set page_title "Upload Contacts CSV"
set page_body ""
set context_bar [im_context_bar $page_title]

set user_is_employee_p [im_user_is_employee_p $current_user_id]
if {!$user_is_employee_p} {
    ad_return_complaint 1 "You have insufficient privileges to use this page"
    return
}


# ---------------------------------------------------------------
# Get the uploaded file
# ---------------------------------------------------------------

# number_of_bytes is the upper-limit
set max_n_bytes [ad_parameter -package_id [im_package_filestorage_id] MaxNumberOfBytes "" 0]
set tmp_filename [ns_queryget upload_file.tmpfile]
im_security_alert_check_tmpnam -location "upload-contacts-2.tcl" -value $tmp_filename
if { $max_n_bytes && ([file size $tmp_filename] > $max_n_bytes) } {
    ad_return_complaint 1 "Your file is larger than the maximum permissible upload size:  [util_commify_number $max_n_bytes] bytes"
    return
}

# strip off the C:\directories... crud and just get the file name
if ![regexp {([^//\\]+)$} $upload_file match company_filename] {
    # couldn't find a match
    set company_filename $upload_file
}

if {[regexp {\.\.} $company_filename]} {
    ad_return_complaint 1 "Filename contains forbidden characters"
}

if {![file readable $tmp_filename]} {
    ad_return_complaint 1 "Unable to read the file '$tmp_filename'. 
Please check the file permissions or contact your system administrator.\n"
    ad_script_abort
}


# ---------------------------------------------------------------
# Extract CSV contents
# ---------------------------------------------------------------

#set csv_files_content [fileutil::cat -encoding "en_US.UTF-8" $tmp_filename]
set fp [open $tmp_filename r]
set csv_files_content [encoding convertfrom utf-8 [read $fp]]
close $fp
set csv_files [split $csv_files_content "\n"]
set csv_files_len [llength $csv_files]

set separator [im_csv_guess_separator $csv_files]

# Split the header into its fields
set csv_header [string trim [lindex $csv_files 0]]
set csv_header_fields [im_csv_split $csv_header $separator]
set csv_header_len [llength $csv_header_fields]
set values_list_of_lists [im_csv_get_values $csv_files_content $separator]


# ---------------------------------------------------------------
# Render Page Header
# ---------------------------------------------------------------

# This page is a "streaming page" without .adp template,
# because this page can become very, very long and take
# quite some time.

ad_return_top_of_page "
        [im_header]
        [im_navbar]
"


# ---------------------------------------------------------------
# Start parsing the CSV
# ---------------------------------------------------------------


set linecount 0
foreach csv_line_fields $values_list_of_lists {
    ns_log Notice "$csv_line_fields"
    incr linecount
    
    # -------------------------------------------------------
    # Extract variables from the CSV file
    # Loop through all columns of the CSV file and set 
    # local variables according to the column header (1st row).

    set var_name_list [list]
    set pretty_field_string ""
    set pretty_field_header ""
    set pretty_field_body ""

    set first_name ""
    set last_name ""
    set email ""
    set street_address ""
    set city ""
    set postal_code ""
    set country ""
    set telephone ""
    set country_list [list]
    set discounts ""
    set partner_discount ""
    set bus_price ""
    
    for {set j 0} {$j < $csv_header_len} {incr j} {

	    set var_name [string trim [lindex $csv_header_fields $j]]
        set var_name [string tolower $var_name]
        set var_name [string map -nocase {" " "_" "\"" "" "'" "" "/" "_" "-" "_"} $var_name]
        set var_name [im_mangle_unicode_accents $var_name]

        # Deal with German Outlook exports
        set var_name [im_upload_cvs_translate_varname $var_name]

        lappend var_name_list $var_name
	
        set var_value [string trim [lindex $csv_line_fields $j]]
        set var_value [string map -nocase {"\"" "" "\{" "(" "\}" ")" "\[" "(" "\]" ")"} $var_value]
        if {[string equal "NULL" $var_value]} { set var_value ""}
        append pretty_field_header "<td>$var_name</td>\n"
        append pretty_field_body "<td>$var_value</td>\n"

        set cmd "set $var_name \"$var_value\""
        set result [eval $cmd]
    }

    set country_code [db_string country_code "select iso from country_codes where lower(country_name)=lower(:country) limit 1" -default ""]

    if {$country_code eq ""} {
        switch $country {
            "Deutschland" - "deutschland" - "D" - "Berlin" - "BRD" - "BED :-)" - "d" {set country_code "de"}
            "Russia" {set country_code "ru"}
            "Österreich" {set country_code "at"}
            "Schweiz" - "schweiz" {set country_code "ch"}
            "USA" - "usa" {set country_code "us"}
            "UK" - "U.K." {set country_code "uk"}
            "Western Australia" {set country_code "au"}
            "Sverige" {set country_code "se"}
            "Italia" {set country_code "it"}
            "España" {set country_code "es"}
            default {ns_write "<li>country missing $country for $first_name $last_name</li>"}
        }
    }
    if {"" == $first_name} {
        ns_write "<li>Error: We have found an empty 'First Name' in line $linecount.<br>
            Error: We can not add users with an empty first name, Please correct the CSV file.
            <br><pre>$pretty_field_string</pre>"
            continue
    }

    if {"" == $last_name} {
        ns_write "<li>Error: We have found an empty 'Last Name' in line $linecount.<br>
            We can not add users with an empty last name. Please correct the CSV file.<br>
            <pre>$pretty_field_string</pre>"
            continue
    }
    
    set user_id [db_string employee "select party_id from parties where lower(email) = lower(:email)" -default ""]
    
    if {"" == $user_id} {
        set user_id [db_string employee "select person_id from persons where 	lower(first_names) = lower(:first_name) 
			and lower(last_name) = lower(:last_name)" -default ""]
        if {"" != $user_id} {
            # We found the user by first_name, last_name combination
            ns_write "<li>Potential Customer Duplicate:: $first_name $last_name with E-Mail :: $email --- Please ammend in the sourcefile or manually create customer"
            continue
        }
    }
    


    set company_id ""
    
    # First create the user
    if {"" == $user_id} {
        set username "$email"
        array set creation_info [auth::create_user -username $username -first_names $first_name -last_name $last_name -email $email -nologin]
        # A successful creation_info looks like:
        # username zahir@zunder.com account_status ok creation_status ok
        # generated_pwd_p 0 account_message {} element_messages {}
        # creation_message {} user_id 302913 password D6E09A4E9

        set creation_status "error"
        if {[info exists creation_info(creation_status)]} { set creation_status $creation_info(creation_status)}
        if {"ok" != [string tolower $creation_status]} {
            ad_return_complaint 1 "<b>[lang::message::lookup "" intranet-contacts.Error_creating_user "Error creating new user"]</b>:<br>
            [lang::message::lookup "" intranet-contacts.Error_creating_user_status "Status"]: $creation_status<br>
            <pre>\n$creation_info(creation_message)\n$creation_info(element_messages)</pre>
            "
            ad_script_abort
        }

        # Extract the user_id from the creation info
        set user_id $creation_info(user_id)

        # Update creation user to allow the creator to admin the user
        db_dml update_creation_user_id "
            update acs_objects
            set creation_user = :current_user_id
            where object_id = :user_id
        "
        set company_name "$first_name $last_name"
    } else {
        db_dml update_names "update persons set first_names = :first_name, last_name = :last_name where person_id = :user_id"
        set company_name "$first_name $last_name"
        regsub -all {[^a-zA-Z0-9]} [string trim [string tolower $company_name]] "_" company_path
        set company_id [db_string company "select company_id from im_companies where company_path = :company_path" -default ""]
        if {$company_id eq ""} {
            set company_id [db_string company "select company_id from im_companies where company_name = :company_name" -default ""]
            db_dml update "update im_companies set company_path = :company_path where company_id = :company_id"
        }
    }

    # Create or replace company information from the user
    if {"" == $company_id} {
        set company_id [im_new_object_id]
        set office_id [im_new_object_id]
        
        set default_company_type_id [im_company_type_customer]
        set company_type_id $default_company_type_id
        set company_status_id [im_company_status_active]
        regsub -all {[^a-zA-Z0-9]} [string trim [string tolower $company_name]] "_" company_path
        set office_path "${company_path}_home"
        
	    set main_office_id [im_office::new \
				    -office_name	"$company_name Home" \
				    -company_id		$company_id \
				    -office_type_id	[im_office_type_main] \
				    -office_status_id	[im_office_status_active] \
				    -office_path	$office_path]

	    # add users to the office as 
	    set role_id [im_biz_object_role_office_admin]
	    im_biz_object_add_role $user_id $main_office_id $role_id
	    
	    # Now create the company with the new main_office:
	    set company_id [im_company::new \
				-company_id		$company_id \
				-company_name		$company_name \
				-company_path		$company_path \
				-main_office_id		$main_office_id \
				-company_type_id	$company_type_id \
				-company_status_id	$company_status_id]
                
        # add users to the company as key account
        set role_id [im_biz_object_role_key_account]
        im_biz_object_add_role $user_id $company_id $role_id
        db_dml update_primary_contact "update im_companies set primary_contact_id = :user_id where company_id = :company_id and primary_contact_id is null"
    } else {
        set main_office_id [db_string main_office "select main_office_id from im_companies where company_id = :company_id"]
    }

    db_dml company "update im_companies set vat_type_id = 42000"


    set contact_found_p [db_string contact_found "select count(*) from users_contact where user_id = :user_id"]
    if {!$contact_found_p} {
        db_dml add_contact "insert into users_contact (user_id) values (:user_id)"
    }

    # Update the address
    db_dml update_contact "update users_contact set ha_line1=:street_address, ha_city = :city, ha_postal_code = :postal_code, ha_country_code = :country_code,  home_phone = :telephone where user_id = :user_id"
    db_dml update_office "update im_offices set address_line1=:street_address, address_city = :city, address_postal_code = :postal_code, address_country_code = :country_code,  phone = :telephone where office_id = :main_office_id "
}

# Remove all permission related entries in the system cache
im_permission_flush


# ------------------------------------------------------------
# Render Report Footer

ns_write [im_footer]
