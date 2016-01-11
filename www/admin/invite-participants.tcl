ad_page_contract {
    Invite Participants to Events
} {
}

# Get the event_options
set event_options [list]
db_foreach events "select event_id as event_id,event_name as event_name from flyhh_events e, im_projects p where e.project_id = p.project_id and p.project_status_id = [im_project_status_open]" {
    lappend event_options [list $event_name $event_id]
}

set content "Dear @first_names@,<p>
we had such a blast with all of you last year that we want to make sure you get a spot in this year’s edition.<br />
You can therefore register already now before the official registration starts next Sunday the 17th of January at noon (12:00PM GMT+1).
</p>
<p>
Please use the following link: 
@link_html;noquote@
</p>
<p>
We have plenty ideas for this year and we are already all excited about what is going to happen when we all meet again at the castle.</p>
Yours truly,<br />
Anna & Malte AND our communication wizard Ulrike
"



set mime_type "text/html"
set content_list [list $content $mime_type]

set form_id "invite_participants"
set action_url "invite-participants"
ad_form \
    -name $form_id \
    -action $action_url \
    -form {
	{event_ids:text(checkbox),multiple,optional
	    {label "[_ intranet-cust-flyhh.Events]:"} 
	    {options  $event_options }
	    {html {checked 1}}
	}
	{to_addr:text(text)
	    {label "[_ acs-mail-lite.Recipients]:"} 
	    {html {size 56}}
	    {help_text "[_ acs-mail-lite.cc_help]"}
	}
	{subject:text(text)
	    {label "[_ acs-mail-lite.Subject]"}
	    {html {size 55}}
	    {value "Personal invitation to pre-register for Castle Camps 2016 (SCC and BCC)"}
	}
	{content_body:text(richtext),optional
	    {label "[_ acs-mail-lite.Message]"}
	    {html {cols 55 rows 18}}
	    {value $content_list}
	}
    } -on_submit {
        set to_addr [split $to_addr ";"]
	foreach event_id $event_ids {
	    db_1row event_info "select event_name from flyhh_events where event_id = :event_id"
	    set event($event_id) $event_name
	}
	foreach email $to_addr {
	    set link_html ""
	    set first_names [db_string first_names "select first_names from persons pe, parties pa where pa.party_id = pe.person_id and pa.email = :email" -default ""]

	    # Invite for each selected event
	    foreach event_id $event_ids {
		set token [ns_sha1 "${email}${event_id}"]
		append link_html "<li><b>$event($event_id): <a href='[export_vars -base "[ad_url]/flyhh/registration" -url {token email event_id}]'>Sign me up!</a></b></li>"
	    }
	    
	    eval [template::adp_compile  -string "$content_body"]
	    set body $__adp_output

	    # send the E-mail
	    acs_mail_lite::send -send_immediately -to_addr $email -from_addr "info@flying-hamburger.de" -subject $subject -body $body -mime_type "text/html"
	    util_user_message -html -message "E-Mail send to $first_names at $email<br />"
	}
    } -after_submit {
	rp_internal_redirect "/packages/intranet-cust-flyhh/www/admin/index"
    }
