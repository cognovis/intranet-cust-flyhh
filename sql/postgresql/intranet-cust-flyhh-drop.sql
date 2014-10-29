delete from im_view_columns where view_id=(select view_id from im_views where view_name='flyhh_event_participants_list');
delete from im_views where view_name='flyhh_event_participants_list';
delete from im_dynfield_type_attribute_map where attribute_id in (
    select a.attribute_id 
    from im_dynfield_attributes a inner join acs_attributes aa on (a.acs_attribute_id=aa.attribute_id) 
    where object_type='flyhh_event_participant'
); 

select im_dynfield_attribute__del(a.attribute_id)
from im_dynfield_attributes a inner join acs_attributes aa on (a.acs_attribute_id = aa.attribute_id)
where object_type='flyhh_event_participant';

select im_dynfield_widget__del(widget_id) 
from im_dynfield_widgets 
where widget_name in ('flyhh_event_participation_accommodation','flyhh_event_participant_food_choice','flyhh_event_participant_bus_options');

drop function flyhh_event_participant__name(integer);
drop function flyhh_event_participant__new(
    integer, varchar, varchar, varchar, varchar,
	integer,
    boolean, varchar, varchar, varchar, boolean,
    integer, integer, integer, integer,
    integer, integer
);

drop function flyhh_person_id_from_email_or_name(integer,varchar,varchar);
drop function flyhh_event_roommate__new(integer,integer,varchar,varchar);

drop table flyhh_event_roommates;
drop table flyhh_event_participants;

delete from im_biz_objects where object_id in (select object_id from acs_objects where object_type='flyhh_event_participant');
delete from acs_objects where object_type='flyhh_event_participant';
delete from acs_object_type_tables where object_type='flyhh_event_participant';
delete from im_dynfield_layout_pages where object_type='flyhh_event_participant';
select acs_object_type__drop_type('flyhh_event_participant',true);

delete from im_categories where category_id in (82500,82501,82502,82503,82504,82505,82506,82510,82511,82512,82513,82514,82515,82516,82517,82518,82550,82551,82552);

