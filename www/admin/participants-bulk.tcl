ad_page_contract {

    @author Neophytos Demetriou (neophytos@azet.sk)
    @creation-date 2014-11-02
    @last-modified 2014-11-04


} {
    bulk_action:trim,notnull
} -validate {

    allowed_bulk_actions -requires {bulk_action} {
        if { -1 == [lsearch -exact [list "Confirm"] $bulk_action] } {
            ad_complain "page requires an allowed bulk action"
        }
    }    
}

switch -exact $bulk_action {
   "Confirm" { 
        rp_internal_redirect participant-confirm.tcl
    }
}
