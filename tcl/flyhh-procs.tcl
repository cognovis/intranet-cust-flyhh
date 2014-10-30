proc flyhh_match_name_email {text nameVar emailVar} {
#
# Simple parsing function to extract name and email from
# a string of the following forms:
#
# firstname lastname email
# firstname lastname
# email
#
# @creation-user Neophytos Demetriou (neophytos@azet.sk)
# @creation-date 2014-10-30
# @last-modified 2014-10-30
#

    upvar $nameVar name
    upvar $emailVar email

    set text [string trim $text]
    set name ""
    set email ""

    set email_re {([^\s\.]+@[^\s\.]+\.(?:[^\s\.]+)+)}
    set name_re {((?:[^\s]+\s+)+[^\s]+)}
    set name_email_re "${name_re}\\s+${email_re}"

    if { ![regexp -- $name_email_re $text _dummy_ name email] } {
        if { ![regexp -- $email_re $text _dummy_ email] } {
            if { ![regexp -- $name_re $text _dummy_ name] } {
                return false
            }
        }
    }
    set name [string trim $name " "]

    ns_log notice ">>>> name=$name email=$email"
    
    return true

}


