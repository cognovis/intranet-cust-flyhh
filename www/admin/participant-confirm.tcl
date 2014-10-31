ad_page_contract {

    Confirmed & Confirmation E-Mail:

    * If we save the registrant in the list page or the edit page and 
      put him/her to confirmed, send out an E-Mail to the registrant 
      that they have a spot for the Camp. The E-Mail should contain 
      what they signed up for as well as a link to get to the payment 
      page for that registration

    * Once we confirm the user, a Quote (invoice type) is created in 
      the system based on the materials used for the registration. This 
      basically is the transformation of the registration into a financial 
      document. We can talk a little bit more about this in skype.

} {
    participant_id:integer,multiple,notnull
    return_url:trim,notnull
}

set sql "select category_id from im_categories where category_type='Flyhh - Event Registration Status' and category='Confirmed'"
set confirmed_status_id [db_string confirmed_status $sql]

set sql "select category_id from im_categories where category_type='Flyhh - Event Registration Status' and category='Waiting List'"
set waiting_list_status_id [db_string waiting_list_status $sql]

set participants_sql_list "([join $participant_id ","])"
set sql "
    update flyhh_event_participants
    set event_participant_status_id=:confirmed_status_id
    where participant_id in $participants_sql_list
    and event_participant_status_id = :waiting_list_status_id
"
db_dml update_status $sql

ad_returnredirect $return_url
