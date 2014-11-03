ad_page_contract {

    @author Neophytos Demetriou (neophytos@azet.sk)
    @creation-date 2014-11-02
    @last-modified 2014-11-03

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

set sql "
    select category_id 
    from im_categories 
    where category_type='Flyhh - Event Registration Status' 
    and category='Confirmed'
"
set confirmed_status_id [db_string confirmed_status $sql]

set sql "
    select category_id 
    from im_categories 
    where category_type='Flyhh - Event Registration Status' 
    and category='Waiting List'
"
set waiting_list_status_id [db_string waiting_list_status $sql]

set sql "
    select project_id,person_id,payment_type,payment_term,company_id
    from flyhh_event_participants
    where participant_id=:participant_id
"
db_1row participant_info $sql

set payment_days [ad_decode "80107" "7" "80114" "14" "80130" "30" "80160" "60" ""]

set provider_id 8720          ;# Company that provides this service - Us
set invoice_date ""
set invoice_status_id "3802"  ;# Intranet Cost Status (3800 = Created)
set invoice_type_id "3700"    ;# Intranet Cost Type (3700 = Customer Invoice, 3702 = Quote)


db_transaction {

    set participants_sql_list "([join $participant_id ","])"
    set sql "
        update flyhh_event_participants
        set event_participant_status_id=:confirmed_status_id
        where participant_id in $participants_sql_list
        and event_participant_status_id = :waiting_list_status_id
    "
    db_dml update_status $sql

    foreach id $participant_id {
        ::flyhh::send_confirmation_mail $id
    }

    # Once we confirm the user, a Quote (invoice type) is created in the system based 
    # on the materials used for the registration. This basically is the transformation 
    # of the registration into a financial document.
    set sql "select project_cost_center_id from im_projects where project_id=:project_id"
    set cost_center_id [db_string cost_center_id $sql]
    set sql "select cost_center_code from im_cost_centers where cost_center_id = :cost_center_id"
    set cost_center_code [db_string cost_center_code $sql]
    set note "$cost_center_code $participant_id"
    set user_id [ad_conn user_id]
    set peeraddr [ad_conn peeraddr]
    set invoice_nr [im_next_invoice_nr -cost_type_id [im_cost_type_invoice]]
    set invoice_id [db_exec_plsql create_invoice "
        select im_invoice__new (
            null,                       -- invoice_id
            'im_invoice',               -- object_type
            now(),                      -- creation_date 
            :user_id,                   -- creation_user
            :peeraddr,                  -- creation_ip
            null,                       -- context_id
            :invoice_nr,                -- invoice_nr
            :company_id,                -- company_id
            :provider_id,               -- provider_id -- us
            :person_id,                 -- company_contact_id
            :invoice_date,              -- invoice_date
            'EUR',                      -- currency
            null,                       -- invoice_template_id
            :invoice_status_id,         -- invoice_status_id
            :invoice_type_id,           -- invoice_type_id
            :payment_type,              -- payment_method_id
            :payment_days,              -- payment_days
            0,                          -- amount
            0,                          -- vat
            0,                          -- tax
            :note                       -- note
         )"]

     # db_dml update_invoice "update im_costs set cost_center_id = :cost_center_id , payment_term_id = 80107, vat_type_id = 42021 where cost_id = :invoice_id"

     # TODO: Add line items for each of the materials

}


ad_returnredirect $return_url
