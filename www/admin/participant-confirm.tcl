ad_page_contract {

    @author Neophytos Demetriou (neophytos@azet.sk)
    @creation-date 2014-11-02
    @last-modified 2014-11-04

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

db_transaction {

    foreach id $participant_id {

        ::flyhh::set_participant_status \
            -participant_id $id \
            -from_status "Waiting List" \
            -to_status "Confirmed"

        ::flyhh::send_confirmation_mail $id

        set sql "
            select project_id,person_id,payment_type,payment_term,company_id,order_id
            from flyhh_event_participants
            where participant_id=:id
        "
        db_1row participant_info $sql

        # skip the parts below if we have already created an order for this participant
        if { $order_id ne {} } {
            continue
        }

        # Once we confirm the user, an Order (invoice type) is created in the system based 
        # on the materials used for the registration. This basically is the transformation 
        # of the registration into a financial document.

        set order_id [::flyhh::create_purchase_order \
                        -company_id ${company_id} \
                        -company_contact_id ${person_id} \
                        -participant_id ${id} \
                        -project_id ${project_id} \
                        -payment_method_id ${payment_type} \
                        -payment_term_id ${payment_term}]

        set sql "update flyhh_event_participants set order_id=:order_id where participant_id=:id"
        db_dml update_participant_info $sql

        # TODO: Add line items for each of the materials

    }

}


ad_returnredirect $return_url


