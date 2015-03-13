ad_page_contract {

    @author malte.sussdorff@cognovis.de
    @creation-date 2015-03-11
    @last-modified 2015-03-11

    Delete a room
    
} {
    room_id:integer
    {remove_occupants_p 0}
    {return_url "rooms-list"}
} 

if {$remove_occupants_p} {db_dml delete_occupants "delete from flyhh_event_room_occupants where room_id = :room_id"}

db_dml delete_room "delete from flyhh_event_rooms where room_id = :room_id"

ad_returnredirect $return_url
