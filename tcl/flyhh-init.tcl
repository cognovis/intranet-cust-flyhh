::flyhh::import_template_file [acs_root_dir]/packages/intranet-cust-flyhh/doc/RechnungCognovis.en.odt

# ad_schedule_proc -thread t 900 ::flyhh::mail_notification_system
ad_schedule_proc -thread t 900 ::flyhh::cleanup_text

# ---------------------------------------------------------------
# Callbacks
# 
# Generically create callbacks for all "package" object types
# ---------------------------------------------------------------

set object_types {
    flyhh_event
    flyhh_event_participant
}

foreach object_type $object_types {

    ad_proc -public -callback ${object_type}_before_create {
    {-object_id:required}
    {-status_id ""}
    {-type_id ""}
    } {
    This callback allows you to execute action before and after every
    important change of object. Examples:
    - Copy preset values into the object
    - Integrate with external applications via Web services etc.

    @param object_id ID of the $object_type 
    @param status_id Optional status_id category. 
           This value is optional. You need to retrieve the status
           from the DB if the value is empty (which should rarely be the case)
           This field allows for quick filtering if the callback 
           implementation is to be executed only on certain object types.
    @param type_id Optional type_id of category.
           This value is optional. You need to retrieve the status
           from the DB if the value is empty (which should rarely be the case)
           This field allows for quick filtering if the callback 
           implementation is to be executed only on certain object states.
    } -

    ad_proc -public -callback ${object_type}_after_create {
    {-object_id:required}
    {-status_id ""}
    {-type_id ""}
    } {
    This callback allows you to execute action before and after every
    important change of object. Examples:
    - Copy preset values into the object
    - Integrate with external applications via Web services etc.

    @param object_id ID of the $object_type 
    @param status_id Optional status_id category. 
           This value is optional. You need to retrieve the status
           from the DB if the value is empty (which should rarely be the case)
           This field allows for quick filtering if the callback 
           implementation is to be executed only on certain object types.
    @param type_id Optional type_id of category.
           This value is optional. You need to retrieve the status
           from the DB if the value is empty (which should rarely be the case)
           This field allows for quick filtering if the callback 
           implementation is to be executed only on certain object states.
    } -



    ad_proc -public -callback ${object_type}_before_update {
    {-object_id:required}
    {-status_id ""}
    {-type_id ""}
    } {
    This callback allows you to execute action before and after every
    important change of object. Examples:
    - Copy preset values into the object
    - Integrate with external applications via Web services etc.

    @param object_id ID of the $object_type 
    @param status_id Optional status_id category. 
           This value is optional. You need to retrieve the status
           from the DB if the value is empty (which should rarely be the case)
           This field allows for quick filtering if the callback 
           implementation is to be executed only on certain object types.
    @param type_id Optional type_id of category.
           This value is optional. You need to retrieve the status
           from the DB if the value is empty (which should rarely be the case)
           This field allows for quick filtering if the callback 
           implementation is to be executed only on certain object states.
    } -

    ad_proc -public -callback ${object_type}_after_update {
    {-object_id:required}
    {-status_id ""}
    {-type_id ""}
    } {
    This callback allows you to execute action before and after every
    important change of object. Examples:
    - Copy preset values into the object
    - Integrate with external applications via Web services etc.

    @param object_id ID of the $object_type 
    @param status_id Optional status_id category. 
           This value is optional. You need to retrieve the status
           from the DB if the value is empty (which should rarely be the case)
           This field allows for quick filtering if the callback 
           implementation is to be executed only on certain object types.
    @param type_id Optional type_id of category.
           This value is optional. You need to retrieve the status
           from the DB if the value is empty (which should rarely be the case)
           This field allows for quick filtering if the callback 
           implementation is to be executed only on certain object states.
    } -



    ad_proc -public -callback ${object_type}_before_delete {
    {-object_id:required}
    {-status_id ""}
    {-type_id ""}
    } {
    This callback allows you to execute action before and after every
    important change of object. Examples:
    - Copy preset values into the object
    - Integrate with external applications via Web services etc.

    @param object_id ID of the $object_type 
    @param status_id Optional status_id category. 
           This value is optional. You need to retrieve the status
           from the DB if the value is empty (which should rarely be the case)
           This field allows for quick filtering if the callback 
           implementation is to be executed only on certain object types.
    @param type_id Optional type_id of category.
           This value is optional. You need to retrieve the status
           from the DB if the value is empty (which should rarely be the case)
           This field allows for quick filtering if the callback 
           implementation is to be executed only on certain object states.
    } -

    ad_proc -public -callback ${object_type}_after_delete {
    {-object_id:required}
    {-status_id ""}
    {-type_id ""}
    } {
    This callback allows you to execute action before and after every
    important change of object. Examples:
    - Copy preset values into the object
    - Integrate with external applications via Web services etc.

    @param object_id ID of the $object_type 
    @param status_id Optional status_id category. 
           This value is optional. You need to retrieve the status
           from the DB if the value is empty (which should rarely be the case)
           This field allows for quick filtering if the callback 
           implementation is to be executed only on certain object types.
    @param type_id Optional type_id of category.
           This value is optional. You need to retrieve the status
           from the DB if the value is empty (which should rarely be the case)
           This field allows for quick filtering if the callback 
           implementation is to be executed only on certain object states.
    } -

    ad_proc -public -callback ${object_type}_view {
    {-object_id:required}
    {-status_id ""}
    {-type_id ""}
    } {
    This callback tracks acess to the object's main page.

    @param object_id ID of the $object_type 
    @param status_id Optional status_id category. 
           This value is optional. You need to retrieve the status
           from the DB if the value is empty (which should rarely be the case)
           This field allows for quick filtering if the callback 
           implementation is to be executed only on certain object types.
    @param type_id Optional type_id of category.
           This value is optional. You need to retrieve the status
           from the DB if the value is empty (which should rarely be the case)
           This field allows for quick filtering if the callback 
           implementation is to be executed only on certain object states.
    } -

    ad_proc -public -callback ${object_type}_form_fill {
        -form_id:required
        -object_id:required
        { -object_type "" }
        { -type_id ""}
        { -page_url "default" }
        { -advanced_filter_p 0 }
        { -include_also_hard_coded_p 0 }
    } {
    This callback tracks acess to the object's main page.

    @param object_id ID of the $object_type 
    @param status_id Optional status_id category. 
           This value is optional. You need to retrieve the status
           from the DB if the value is empty (which should rarely be the case)
           This field allows for quick filtering if the callback 
           implementation is to be executed only on certain object types.
    @param type_id Optional type_id of category.
           This value is optional. You need to retrieve the status
           from the DB if the value is empty (which should rarely be the case)
           This field allows for quick filtering if the callback 
           implementation is to be executed only on certain object states.
    } -

    ad_proc -public -callback ${object_type}_on_submit {
        -form_id:required
        -object_id:required
    } {
        This callback allows for additional validations and it should be called in the on_submit block of a form

        Usage: 
            form set_error $form_id $error_field $error_message
            break

        @param object_id ID of the $object_type
        @param form_id ID of the form which is being submitted
    } -


}
