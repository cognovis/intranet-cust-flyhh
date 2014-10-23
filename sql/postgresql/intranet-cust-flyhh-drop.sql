delete from im_view_columns where view_id=(select view_id from im_views where view_name='event_participants_list');
delete from im_views where view_name='event_participants_list';
delete from im_dynfield_type_attribute_map where attribute_id in (
    select a.attribute_id 
    from im_dynfield_attributes a inner join acs_attributes aa on (a.acs_attribute_id=aa.attribute_id) 
    where object_type='im_event_participant'
); 

select im_dynfield_attribute__del(a.attribute_id)
from im_dynfield_attributes a inner join acs_attributes aa on (a.acs_attribute_id = aa.attribute_id)
where object_type='im_event_participant';

select im_dynfield_widget__del(widget_id) 
from im_dynfield_widgets 
where widget_name in ('event_participation_accommodation','event_participant_food_choice','event_participant_bus_options');

drop function im_event_participant__name(integer);
drop function im_event_participant__new(
    integer, varchar, varchar, varchar, varchar,
	integer, integer, integer,
    boolean, varchar, boolean,
    integer, integer, integer, integer,
    integer, integer
);

drop table im_event_roommates;
drop table im_event_participants;

delete from im_biz_objects where object_id in (select object_id from acs_objects where object_type='im_event_participant');
delete from acs_objects where object_type='im_event_participant';
delete from acs_object_type_tables where object_type='im_event_participant';
delete from im_dynfield_layout_pages where object_type='im_event_participant';
select acs_object_type__drop_type('im_event_participant',true);
