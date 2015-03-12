ad_page_contract {

    Return a PDF of the invoice

    @author Malte Sussdorff (malte.sussdorff@cognovis.de)
    @creation-date 2011-04-27
    @cvs-id $Id$
} {
    invoice_id:notnull
    participant_id:notnull
}

# Check if the invoice_id belongs to the participant
set invoice_id_from_participant [db_string invoice "select invoice_id from flyhh_event_participants where participant_id = :participant_id" -default ""]
if {$invoice_id ne $invoice_id_from_participant} {
    ad_return_error "Invalid Invoice" "You are trying to access an invoice you should not have access to."    
}

db_1row invoice_info "select invoice_nr,last_modified from im_invoices,acs_objects where invoice_id = :invoice_id and invoice_id = object_id"

set invoice_item_id [content::item::get_id_by_name -name "${invoice_nr}.pdf" -parent_id $invoice_id]

if {"" == $invoice_item_id} {
    set invoice_revision_id [intranet_openoffice::invoice_pdf -invoice_id $invoice_id]
} else {
    set invoice_revision_id [content::item::get_best_revision -item_id $invoice_item_id]

    # Check if we need to create a new revision
    if {[db_string date_check "select 1 from acs_objects where object_id = :invoice_revision_id and last_modified < :last_modified" -default 0]} {
        set invoice_revision_id [intranet_openoffice::invoice_pdf -invoice_id $invoice_id]
    }
}

set outputheaders [ns_conn outputheaders]
ns_set cput $outputheaders "Content-Disposition" "attachment; filename=${invoice_nr}.pdf"
ns_returnfile 200 application/pdf [content::revision::get_cr_file_path -revision_id $invoice_revision_id]