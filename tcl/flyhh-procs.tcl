namespace eval ::flyhh {;}

proc ::flyhh::match_name_email {text nameVar emailVar} {
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
# @last-modified 2014-11-02
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

proc ::flyhh::send_confirmation_mail {participant_id} {
#
# @creation-user Neophytos Demetriou (neophytos@azet.sk)
# @creation-date 2014-11-02
# @last-modified 2014-11-02
#

    set sql "
        select 
            *, 
            party__email(person_id) as email, 
            person__name(person_id) as name,
            flyhh_event__name_from_project_id(project_id) as event_name,
            im_name_from_id(accommodation) as accommodation,
            im_name_from_id(food_choice) as food_choice,
            im_name_from_id(bus_option) as bus_option
        from flyhh_event_participants 
        where participant_id=:participant_id
    "
    db_1row participant_info $sql

    # The payment page checks that the logged in user and the participant_id are 
    # the same (so you can’t confirm on behalf of someone else). We could make it
    # more flexible by having a unique token that signs the link we sent out.
    #
    set current_location [util_current_location]
    set link_to_payment_page "${current_location}/flyhh/payment?participant_id=${participant_id}"
    set from_addr "noreply-${participant_id}@flying-hamburger.de"
    set to_addr ${email}
    set mime_type "text/plain"
    set subject "Event Registration Confirmation for ${name}"
    set body "
Hi ${name},

We have reserved a spot for you for \"${event_name}\".

Here's what you have signed up for:
Accommodation: ${accommodation}
Food Choice: ${food_choice}
Bus Option: ${bus_option}

To complete the registration, please proceed with payment at the following page:
${link_to_payment_page}
"

    acs_mail_lite::send \
        -from_addr $from_addr \
        -to_addr $to_addr \
        -body $body \
        -mime_type $mime_type \
        -object_id $participant_id

    # TODO: record confirmation_mail_sent_p flag in participants table and confirmation_mail_date
    # and consider storing the delivery date (we need to figure out how to use callbacks for that)

}
