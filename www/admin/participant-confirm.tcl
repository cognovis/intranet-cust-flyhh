ad_page_contract {

    @author Neophytos Demetriou (neophytos@azet.sk)
    @creation-date 2014-11-02
    @last-modified 2014-11-14

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
    project_id:integer,notnull
    participant_id:integer,multiple,notnull
    return_url:trim,notnull
} -validate {
    check_confirmed_free_capacity -requires {project_id:integer participant_id:integer} {
        ::flyhh::check_confirmed_free_capacity -project_id $project_id -participant_id_list $participant_id
    }
}

# Get the list of partners for the participants who are not confirmed yet and append them. 
# Also filter out anyone who is not on the Waiting list
set participant_ids [db_list participant_ids "
        select e.partner_participant_id 
          from flyhh_event_participants e, flyhh_event_participants p
         where e.participant_id in ([template::util::tcl_to_sql_list $participant_id])
           and p.participant_id = e.partner_participant_id
           and p.partner_mutual_p = true
           and e.partner_mutual_p = true
           and p.event_participant_status_id = [im_category_from_category -category "Waiting List"]
        UNION
        select participant_id
          from flyhh_event_participants 
         where participant_id in ([template::util::tcl_to_sql_list $participant_id])
           and event_participant_status_id = [im_category_from_category -category "Waiting List"]
    "
    ]

db_transaction {

    foreach id $participant_ids {

        ::flyhh::set_participant_status \
            -participant_id $id \
            -from_status "Waiting List" \
            -to_status "Confirmed"

        set sql "
            select project_id,person_id,payment_type,payment_term,company_id,quote_id
            from flyhh_event_participants
            where participant_id=:id
        "
        db_1row participant_info $sql

        # skip the parts below if we have already created an order for this participant
        if { $quote_id ne {} } {
            continue
        }

        # Once we confirm the user, an Order (invoice type) is created in the system based 
        # on the materials used for the registration. This basically is the transformation 
        # of the registration into a financial document.

        set quote_id [::flyhh::create_quote \
                        -company_id ${company_id} \
                        -company_contact_id ${person_id} \
                        -participant_id ${id} \
                        -project_id ${project_id} \
                        -payment_method_id ${payment_type} \
                        -payment_term_id ${payment_term}]

        set sql "update flyhh_event_participants set quote_id=:quote_id where participant_id=:id"
        db_dml update_participant_info $sql

        ::flyhh::send_confirmation_mail $id

    }

}


ad_returnredirect $return_url


