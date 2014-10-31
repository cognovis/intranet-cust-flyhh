ad_page_contract {
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
