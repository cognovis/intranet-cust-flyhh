ad_page_contract {
    Payment Page
} {
    participant_id:integer,notnull
} -validate {

    check_user_is_same -requires {participant_id:integer} {

        set user_id [ad_conn user_id]

        set sql "select person_id from flyhh_event_participants where participant_id=:participant_id"
        set participant_person_id [db_string participant_person_id $sql -default ""]
        
        if { ${user_id} ne ${participant_person_id} } { 
            ad_complain "logged in user and participant must be the same"
        }

    }

}

set sql "
    select category_id 
    from im_categories 
    where category_type='Flyhh - Event Registration Status'
    and category='Pending Payment'
"
set pending_payment_status_id [db_string pending_payment_status_id $sql]

set sql "
    select category_id 
    from im_categories 
    where category_type='Flyhh - Event Registration Status'
    and category='Confirmed'
"
set confirmed_status_id [db_string confirmed_status_id $sql]

set sql "
    update flyhh_event_participants set event_participant_status_id=:pending_payment_status_id 
    where participant_id=:participant_id and event_participant_status_id=:confirmed_status_id"
db_dml update_status $sql

# NOT IMPLEMENTED YET
ns_return 200 text/plain "not implemented yet"
