ad_page_contract {
    Payment Page
} {
    participant_id:integer,notnull
    token:notnull
}

set error_text ""
set adp_master "master-bcc"
set locale "en_US"

db_1row participant_info "select * from flyhh_event_participants where participant_id = :participant_id"

# check that the token is correct
set check_token [ns_sha1 "${participant_id}${project_id}"]
if {$token ne $check_token} {
    set error_text "Illegal Token - You should not edit the link!"
}

if {$error_text eq ""} {
    
    db_1row event_info "select project_cost_center_id, p.project_id, event_url, event_email from flyhh_events f, im_projects p where p.project_id = :project_id and p.project_id = f.project_id"
    
    if {$event_participant_status_id eq "[::flyhh::status_id_from_name "Confirmed"]"} {
        ::flyhh::set_participant_status \
            -participant_id ${participant_id} \
            -from_status "Confirmed" \
            -to_status "Pending Payment"
    }
    
    # Check if the invoice is already created, otherwise create it.
    if {$invoice_id eq ""} {
        
        # When the customer confirms he wants to participate in the event,
        # we create an invoice from the purchase order
    
        # Intranet Cost Type
        # (3700 = Customer Invoice)
        set invoice_id [im_invoice_copy_new -source_invoice_ids $quote_id -target_cost_type_id [im_cost_type_invoice]]
    
        set sql "
            update flyhh_event_participants 
            set invoice_id=:invoice_id 
            where participant_id=:participant_id
        "
        db_dml update_participant_info $sql
        
        # Update the quote to accepted and change the last modified date to record this

        set sql "
            update im_costs 
            set cost_status_id = [im_cost_status_accepted],
            delivery_date = now()
            where cost_id = :quote_id
        "
        db_dml update_cost_status $sql
    }
        
    # An E-Mail is send to the participant with the PDF attached and the payment 
    # information similar to what is displayed on the Web site.
    ::flyhh::send_invoice_mail -invoice_id $invoice_id -from_addr $event_email -project_id $project_id
    
    # The webpage should display the†information what has been provided with the registration,
    # a link to the PDF invoice for review, the total amount, the due date (based on the time 
    # the link was clicked and the payment terms).
    
    set invoice_pdf_link "test"
#    set invoice_pdf_link "invoice-pdf/invoice_${participant_id}_${new_invoice_id}_${invoice_revision_id}.pdf"
 
    set invoice_nr [db_string invoice_nr "select invoice_nr from im_invoices where invoice_id = :invoice_id"]
    set full_name [im_name_from_user_id $person_id]
    
    # CREATE a table with all the invoice items in it
    set sql "select
        i.*,
        now() as delivery_date_pretty,
        im_category_from_id(i.item_type_id) as item_type,
        im_category_from_id(i.item_uom_id) as item_uom,
        coalesce(round(i.price_per_unit * i.item_units * :rf),0) / :rf as amount,
        to_char(coalesce(round(i.price_per_unit * i.item_units * :rf),0) / :rf, :cur_format) as amount_formatted,
        i.currency as item_currency
      from
        im_invoice_items i
      where
        i.invoice_id=:invoice_id
      order by
        i.sort_order,
        i.item_type_id"

    # start formatting the list of sums with the header...
    set invoice_item_html "<tr align=center>
        <td class=rowtitle align=right>[lang::message::lookup $locale intranet-invoices.Line_no '#']</td>
        <td class=rowtitle align=left>[lang::message::lookup $locale intranet-invoices.Description]&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>
        <td class=rowtitle align=right>[lang::message::lookup $locale intranet-invoices.Amount]</td>
        </tr>"
        
    set ctr 1
    set subtotal 0
    set cur_format [im_l10n_sql_currency_format]
    set rounding_precision 2
    set rounding_factor [expr exp(log(10) * $rounding_precision)]
    set rf $rounding_factor
    set bgcolor(0) "class=invoiceroweven"
    set bgcolor(1) "class=invoicerowodd"
    
    db_foreach invoice_items $sql {
        
        set amount_pretty [lc_numeric [im_numeric_add_trailing_zeros [expr $amount+0] $rounding_precision] "" $locale]
        append invoice_item_html "
            <tr $bgcolor([expr $ctr % 2])>
                <td $bgcolor([expr $ctr % 2]) align=right>$sort_order</td>
                <td $bgcolor([expr $ctr % 2]) align=left>$item_name</td>
                <td $bgcolor([expr $ctr % 2]) align=right>$amount_pretty&nbsp;$currency</td>
            </tr>
        "
        set subtotal [expr $subtotal + $amount]
    }
    
    # Calculate the total sum plus the minimum payment (Anzahlung)

    set total_due_pretty [lc_numeric [im_numeric_add_trailing_zeros [expr $subtotal+0] $rounding_precision] "" $locale]
    set due_now_pretty [lc_numeric [im_numeric_add_trailing_zeros [expr $subtotal*0.3 +0] $rounding_precision] "" $locale]
    append invoice_item_html "
        <tr>
          <td class=roweven colspan=2 align=right><b>[lang::message::lookup $locale intranet-invoices.Total_Due]</b></td>
          <td class=roweven align=right><b><nobr>$total_due_pretty $currency</nobr></b></td>
        </tr>
    "
    
}

