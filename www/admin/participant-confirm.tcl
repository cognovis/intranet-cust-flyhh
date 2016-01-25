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

set unlimited_accommodation_ids [db_list accommodation "select material_id from flyhh_event_materials em, flyhh_events e where e.event_id = em.event_id and capacity = 999 and project_id = :project_id"] 

set participant_ids [db_list participant_ids "
        select e.partner_participant_id 
          from flyhh_event_participants e, flyhh_event_participants p left outer join flyhh_event_room_occupants ro on (p.person_id = ro.person_id and p.project_id = ro.project_id) 
         where e.participant_id in ([template::util::tcl_to_sql_list $participant_id])
           and p.participant_id = e.partner_participant_id
           and p.partner_mutual_p = true
           and e.partner_mutual_p = true
           and p.event_participant_status_id = [im_category_from_category -category "Waiting List"]
           and (ro.room_id is not null or p.accommodation in ([template::util::tcl_to_sql_list $unlimited_accommodation_ids]))
        UNION
        select ep.participant_id
          from flyhh_event_participants ep left outer join flyhh_event_room_occupants ro on (ep.person_id = ro.person_id and ep.project_id = ro.project_id) 
         where ep.participant_id in ([template::util::tcl_to_sql_list $participant_id])
           and ep.event_participant_status_id = [im_category_from_category -category "Waiting List"]
           and (ro.room_id is not null or ep.accommodation in ([template::util::tcl_to_sql_list $unlimited_accommodation_ids]))
    "
    ]

db_1row event_info "select project_cost_center_id, p.project_id, f.* from flyhh_events f, im_projects p where p.project_id = :project_id and p.project_id = f.project_id"

    foreach id $participant_ids {

        ::flyhh::set_participant_status \
            -participant_id $id \
            -from_status "Waiting List" \
            -to_status "Pending Payment"

        set sql "
            select project_id,person_id,payment_type,payment_term,company_id,invoice_id
            from flyhh_event_participants
            where participant_id=:id
        "
        db_1row participant_info $sql

        # skip the parts below if we have already created an order for this participant
        if { $invoice_id ne {} } {
            continue
        }

        # Once we confirm the user, an Order (invoice type) is created in the system based 
        # on the materials used for the registration. This basically is the transformation 
        # of the registration into a financial document.

        set invoice_id [::flyhh::create_invoice \
                        -company_id ${company_id} \
                        -company_contact_id ${person_id} \
                        -participant_id ${id} \
                        -project_id ${project_id} \
                        -payment_method_id ${payment_type} \
                        -payment_term_id ${payment_term} \
                        -invoice_type_id [im_cost_type_invoice]]

        set sql "update flyhh_event_participants set invoice_id=:invoice_id where participant_id=:id"
                
        db_dml update_participant_info $sql

        # An E-Mail is send to the participant with the PDF attached and the payment 
        # information similar to what is displayed on the Web site.
        ::flyhh::send_invoice_mail -invoice_id $invoice_id -from_addr $event_email -project_id $project_id
        
    }

ad_returnredirect $return_url


