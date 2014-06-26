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

set user_is_admin_p [im_is_user_site_wide_or_intranet_admin $current_user_id]
if {!$user_is_admin_p} {
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
            default {ds_comment "country missing $country for $first_name $last_name"}
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
            ds_comment "Potential Customer Duplicate:: $first_name $last_name with E-Mail :: $email --- Please ammend in the sourcefile or manually create customer"
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

    if {$total_cost eq "0.00"} {
        ds_comment "skipping $first_name $last_name"
        continue
    }
    
    set event_name [db_string cost_center "select cost_center_code from im_cost_centers where cost_center_id = :cost_center_id"]
    
    set created_invoice_p 0
    if {$status == "accepted"} {
    
        # Check if we have the invoice already
        # Store the reference_id in the note
        set note "$event_name $bookingid"
        set invoice_id [db_string invoice "select cost_id from im_costs where note = :note" -default ""]
        
        # Find out the invoice date
        set invoice_date [lindex [split $creation_date " "] 0]
        if {$invoice_date < "2014-04-01"} {set invoice_date "2014-04-01"}
        if {$invoice_id eq ""} {
            set invoice_nr [im_next_invoice_nr -cost_type_id [im_cost_type_invoice]]
            set invoice_id [db_exec_plsql create_invoice "select im_invoice__new (
            :invoice_id,		-- invoice_id
  		    'im_invoice',		-- object_type
  		    now(),			-- creation_date 
            [ad_conn user_id],		-- creation_user
            '[ad_conn peeraddr]',	-- creation_ip
  		    null,			-- context_id
            :invoice_nr,		-- invoice_nr
            :company_id,		-- company_id
            8720,		-- provider_id -- us
  		    null,			-- company_contact_id
            :invoice_date,		-- invoice_date
  		    'EUR',			-- currency
            null,		-- invoice_template_id
            3802,	-- invoice_status_id
            3700,		-- invoice_type_id
            804,	-- payment_method_id
            7,		-- payment_days
            :total_cost,			-- amount
            0,			-- vat
            0,			-- tax
            :note			-- note
         )"]
             set created_invoice_p 1
             db_dml update_invoice "update im_costs set cost_center_id = :cost_center_id , payment_term_id = 80107, vat_type_id = 42021 where cost_id = :invoice_id"
             ds_comment "Invoice $invoice_nr created for company $company_name with ID $invoice_id"
             
         }
    }
     
    # Only if we created the invoice we will add the line items, otherwise we highlight differences
    
    # Classes
    # Materials Type: 9004 - Classes 

    set classes_item_id [db_string classes "select item_id from im_invoice_items where invoice_id = :invoice_id and item_material_id in (select material_id from im_materials where material_type_id = 9004) and price_per_unit >0" -default ""]
    set classes [string trimleft $classes "1x "]
    db_1row class_material "select im.material_id as classes_material_id, material_name as classes_material_name, material_uom_id as classes_uom_id, price as classes_price 
     from im_materials im, im_timesheet_prices itp where material_nr = :classes and im.material_id = itp.material_id and company_id = 8720 limit 1"
    if {"" == $classes_item_id && $created_invoice_p == 0} {
        if {"" != $classes} {
                        
             set classes_item_id [db_nextval "im_invoice_items_seq"]
             set insert_invoice_items_sql "
            INSERT INTO im_invoice_items (
                    item_id, item_name,
                    project_id, invoice_id,
                    item_units, item_uom_id,
                    price_per_unit, currency,
                    sort_order, item_type_id,
                    item_material_id,
                    item_status_id, description, task_id,
    		item_source_invoice_id
            ) VALUES (
                    :classes_item_id, :classes_material_name,
                    null, :invoice_id,
                    1, :classes_uom_id,
                    :classes_price, 'EUR',
                    1, null,
                    :classes_material_id,
                    null, '',null,null
    	    )" 
            db_dml insert_invoice_items $insert_invoice_items_sql
            ds_comment "$classes for $classes_price created for company $company_name with ID $invoice_id"
            
        }
    } 
    
    # Compare the values
    if {"" != $classes_item_id} {
        db_1row compare "select item_material_id, item_units from im_invoice_items where item_id = :classes_item_id"
        if {$classes_material_id ne $item_material_id || $item_units ne 1.00} {
            ds_comment "$company_name CLASSES:: $invoice_id :: $classes_material_id - $item_material_id :: $item_units"
        }
    }
        
    # Accomodation
    # Materials Type: 9002 - acommodation 
    set accom_item_id [db_string accom "select item_id from im_invoice_items where invoice_id = :invoice_id and item_material_id in (select material_id from im_materials where material_type_id = 9002) and price_per_unit >0" -default ""]
    if {"" == $accom_item_id && $created_invoice_p == 0} {
        set accom [string trimleft $acc_room "1x "]
            
        if {$accom == "external"} {
            #do nothing
        } else {
            db_1row class_material "select im.material_id as accom_material_id, material_name as accom_material_name, material_uom_id as accom_uom_id, price as accom_price 
                     from im_materials im, im_timesheet_prices itp where material_nr = :accom and im.material_id = itp.material_id and company_id = 8720 limit 1"
        	set accom_item_id [db_nextval "im_invoice_items_seq"]
            
            set insert_invoice_items_sql "
                 INSERT INTO im_invoice_items (
                    item_id, item_name,
                    project_id, invoice_id,
                    item_units, item_uom_id,
                    price_per_unit, currency,
                    sort_order, item_type_id,
                    item_material_id,
                    item_status_id, description, task_id,
    		        item_source_invoice_id
                    ) VALUES (
                    :accom_item_id, :accom_material_name,
                    null, :invoice_id,
                    1, :accom_uom_id,
                    :accom_price, 'EUR',
                    2, null,
                    :accom_material_id,
                    null, '',null,null
                    )" 

            db_dml insert_invoice_items $insert_invoice_items_sql
        }
    } 
    
    if {"" != $accom_item_id} {
        # Compare the values
        db_1row compare "select price_per_unit, item_units from im_invoice_items where item_id = :accom_item_id"
        set acc_room__price [format "%.2f" [expr $acc_room__price / "1.07"]]
        set price_per_unit [format "%.2f" $price_per_unit]
        if {$acc_room__price ne $price_per_unit || $item_units ne 1.00} {ds_comment "$company_name ACCOM :: $invoice_id :: $price_per_unit - $acc_room__price :: $item_units"}    
    }
        
    # Meals - Parties
    # Materials Type: 900 - Meals 
    set meals_item_id [db_string meals "select item_id from im_invoice_items where invoice_id = :invoice_id and item_material_id in (33313,33314)" -default ""]
    if {"" == $meals_item_id && $created_invoice_p == 0} {

        set meals [string trimleft $meals_parties "1x "]    
        db_1row class_material "select im.material_id as meals_material_id, material_name as meals_material_name, material_uom_id as meals_uom_id, price as meals_price 
                 from im_materials im, im_timesheet_prices itp where material_nr = :meals and im.material_id = itp.material_id and company_id = 8720 limit 1"
        
        set meals_parties__price [format "%.2f" [expr $meals_parties__price / "1.19"]]
        set meals_price [format "%.2f" $meals_price]
        
        if {$meals_parties__price ne $meals_price} {
            ds_comment "Great, different pricing $company_name for meals $meals_parties__price instead of $meals_price"
            set meals_price $meals_parties__price
        }
        
    	set meals_item_id [db_nextval "im_invoice_items_seq"]
        set insert_invoice_items_sql "
            INSERT INTO im_invoice_items (
                    item_id, item_name,
                    project_id, invoice_id,
                    item_units, item_uom_id,
                    price_per_unit, currency,
                    sort_order, item_type_id,
                    item_material_id,
                    item_status_id, description, task_id,
    		item_source_invoice_id
            ) VALUES (
                    :meals_item_id, :meals_material_name,
                    null, :invoice_id,
                    1, :meals_uom_id,
                    :meals_price, 'EUR',
                    3, null,
                    :meals_material_id,
                    null, '',null,null
    	    )" 

        db_dml insert_invoice_items $insert_invoice_items_sql
    } 
    
    if {"" != $meals_item_id} {
        # Compare the values
        db_1row compare "select price_per_unit, item_units from im_invoice_items where item_id = :meals_item_id"
        set meals_parties__price [format "%.2f" [expr $meals_parties__price / "1.19"]]
        set price_per_unit [format "%.2f" $price_per_unit]
        if {$meals_parties__price ne $price_per_unit || $item_units ne 1.00} {ds_comment "$company_name MEALS :: $invoice_id :: $price_per_unit - $meals_parties__price :: $item_units"}    
    }
    
    set partner_item_id [db_string partner "select item_id from im_invoice_items where invoice_id = :invoice_id and item_material_id = 34830" -default ""]
    
    # Handle SCC Partner discount
    if {"" == $partner_item_id && $created_invoice_p == 0} {
        
        db_1row class_material "select im.material_id as partner_material_id, material_name as partner_material_name, material_uom_id as partner_uom_id, price as partner_price 
                 from im_materials im, im_timesheet_prices itp where im.material_id = 34830 and im.material_id = itp.material_id and company_id = 8720 limit 1"

        # Check if we have a partner rebate
        if {$partner_discount == "Yes"} {
            set partner_item_id [db_nextval "im_invoice_items_seq"]
            set insert_invoice_items_sql "
                     INSERT INTO im_invoice_items (
                             item_id, item_name,
                             project_id, invoice_id,
                             item_units, item_uom_id,
                             price_per_unit, currency,
                             sort_order, item_type_id,
                             item_material_id,
                             item_status_id, description, task_id,
             		item_source_invoice_id
                     ) VALUES (
                             :partner_item_id, :partner_material_name,
                             null, :invoice_id,
                             1, :partner_uom_id,
                             :partner_price, 'EUR',
                             4, null,
                             :partner_material_id,
                             null, '',null,null
             	    )" 

            db_dml insert_invoice_items $insert_invoice_items_sql            
        }
    } 
    
    if {"" != $partner_item_id} {
        # Compare the values
        db_1row compare "select price_per_unit, item_units from im_invoice_items where item_id = :partner_item_id"
        set price_per_unit [format "%.2f" $price_per_unit]
        set partner_price [format "%.2f" $partner_price]
        if {$partner_price ne $price_per_unit || $item_units ne 1.00} {ds_comment "$company_name SCC PARTNER :: $invoice_id :: $price_per_unit - $partner_price :: $item_units"}    
    }
                
    # Handle Partner discount
        
    set partner_item_id [db_string partner "select item_id from im_invoice_items where invoice_id = :invoice_id and item_material_id = 34830" -default ""]
    if {"" == $partner_item_id && $created_invoice_p == 0} {            
        db_1row class_material "select im.material_id as partner_material_id, material_name as partner_material_name, material_uom_id as partner_uom_id, price as partner_price 
                 from im_materials im, im_timesheet_prices itp where im.material_id = 34830 and im.material_id = itp.material_id and company_id = 8720 limit 1"

        # Check if we have a partner rebate
        if {[string match -nocase "*partner*" $discounts]} {
        	set partner_item_id [db_nextval "im_invoice_items_seq"]
            set insert_invoice_items_sql "
                     INSERT INTO im_invoice_items (
                             item_id, item_name,
                             project_id, invoice_id,
                             item_units, item_uom_id,
                             price_per_unit, currency,
                             sort_order, item_type_id,
                             item_material_id,
                             item_status_id, description, task_id,
             		item_source_invoice_id
                     ) VALUES (
                             :partner_item_id, :partner_material_name,
                             null, :invoice_id,
                             1, :partner_uom_id,
                             :partner_price, 'EUR',
                             4, null,
                             :partner_material_id,
                             null, '',null,null
             	    )" 

            db_dml insert_invoice_items $insert_invoice_items_sql
        }
    } 
    
    if {"" != $partner_item_id} {
        # Compare the values
        db_1row compare "select price_per_unit, item_units from im_invoice_items where item_id = :partner_item_id"
        set price_per_unit [format "%.2f" $price_per_unit]
        set partner_price [format "%.2f" $partner_price]
        if {$partner_price ne $price_per_unit || $item_units ne 1.00} {ds_comment "$company_name BCC Partner :: $invoice_id :: $price_per_unit - $partner_price :: $item_units"}    
    }
        
    # Handle SCC discount
        
    set scc_item_id [db_string scc "select item_id from im_invoice_items where invoice_id = :invoice_id and item_material_id = 34829" -default ""]
    if {"" == $scc_item_id && $created_invoice_p == 0} {
        db_1row class_material "select im.material_id as scc_material_id, material_name as scc_material_name, material_uom_id as scc_uom_id, price as scc_price 
                 from im_materials im, im_timesheet_prices itp where im.material_id = 34829 and im.material_id = itp.material_id and company_id = 8720 limit 1"
        # Check if we have a scc rebate
        if {[string match -nocase "*scc*" $discounts]} {
        	set scc_item_id [db_nextval "im_invoice_items_seq"]
            set insert_invoice_items_sql "
                     INSERT INTO im_invoice_items (
                             item_id, item_name,
                             project_id, invoice_id,
                             item_units, item_uom_id,
                             price_per_unit, currency,
                             sort_order, item_type_id,
                             item_material_id,
                             item_status_id, description, task_id,
             		item_source_invoice_id
                     ) VALUES (
                             :scc_item_id, :scc_material_name,
                             null, :invoice_id,
                             1, :scc_uom_id,
                             :scc_price, 'EUR',
                             5, null,
                             :scc_material_id,
                             null, '',null,null
             	    )" 

            db_dml insert_invoice_items $insert_invoice_items_sql            
        }
    } 
    
    if {"" != $scc_item_id} {
        # Compare the values
        db_1row compare "select price_per_unit, item_units from im_invoice_items where item_id = :scc_item_id"
        set price_per_unit [format "%.2f" $price_per_unit]
        set scc_price [format "%.2f" $scc_price]
        if {$scc_price ne $price_per_unit || $item_units ne 1.00} {ds_comment "$company_name SCC Discount :: $invoice_id :: $price_per_unit - $scc_price :: $item_units"}    
    }
     
    
    set bus_material_id ""
    if {[string match -nocase "*round trip*" $bus_shuttle]} { set bus_material_id 34833}
    if {[string match -nocase "*one way*" $bus_shuttle]} { set bus_material_id 34832}
        
    # Handle Bus tickets
    set bus_item_id [db_string bus "select item_id from im_invoice_items where invoice_id = :invoice_id and item_material_id = :bus_material_id" -default ""]
    if {"" == $bus_item_id && $created_invoice_p == 0} {

        
        # Check if we have a bus rebate
        if {"" != $bus_material_id} {
        	set bus_item_id [db_nextval "im_invoice_items_seq"]
            db_1row class_material "select material_name as bus_material_name, material_uom_id as bus_uom_id, price as bus_price 
                         from im_materials im, im_timesheet_prices itp where im.material_id = :bus_material_id and im.material_id = itp.material_id and company_id = 8720 limit 1"
            set insert_invoice_items_sql "
                     INSERT INTO im_invoice_items (
                             item_id, item_name,
                             project_id, invoice_id,
                             item_units, item_uom_id,
                             price_per_unit, currency,
                             sort_order, item_type_id,
                             item_material_id,
                             item_status_id, description, task_id,
             		item_source_invoice_id
                     ) VALUES (
                             :bus_item_id, :bus_material_name,
                             null, :invoice_id,
                             1, :bus_uom_id,
                             :bus_price, 'EUR',
                             6, null,
                             :bus_material_id,
                             null, '',null,null
             	    )" 

            db_dml insert_invoice_items $insert_invoice_items_sql
        } 
    } 
    
    if {"" != $bus_item_id} {
        # Compare the values
        db_1row compare "select price_per_unit, item_units from im_invoice_items where item_id = :bus_item_id"
        set price_per_unit [format "%.2f" $price_per_unit]
        set bus_shuttle__price [format "%.2f" [expr $bus_shuttle__price / "1.19"]]
        if {$bus_shuttle__price ne $price_per_unit || $item_units ne 1.00} {ds_comment "$company_name BUS :: $invoice_id :: $price_per_unit - $bus_shuttle__price :: $item_units"}    
    } 
        
    # Update the total amount
    set total_amount [db_string total "select sum(round(item_units*price_per_unit,2)+round(item_units*price_per_unit*cb.aux_int1/100,2))
                                                 from im_invoice_items ii, im_categories ca, im_categories cb, im_materials im 
                                                where invoice_id = :invoice_id
                                                  and ca.category_id = material_type_id
                                                  and ii.item_material_id = im.material_id
                                                  and ca.aux_int2 = cb.category_id"]
    
    set total_net_amount [db_string total "select round(sum(item_units*price_per_unit),2) from im_invoice_items where invoice_id = :invoice_id"]
        
#        set total_amount [expr $total_net_amount + $total_vat_amount]
#        append total_amount 0
    if {$total_amount eq $total_cost} {
        db_dml update_invoice {update im_costs set amount = :total_net_amount where cost_id = :invoice_id}
        intranet_collmex::update_customer_invoice -invoice_id $invoice_id        
    } else {
        ds_comment "ERROR with total amount $first_name $last_name :: $total_cost :: $total_amount"
    }     
}

# Remove all permission related entries in the system cache
im_permission_flush


# ------------------------------------------------------------
# Render Report Footer

ns_write [im_footer]
