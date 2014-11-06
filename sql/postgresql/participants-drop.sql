-- @author Neophytos Demetriou
-- @creation-date 2014-10-30
-- @last-modified 2014-10-30

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
drop function flyhh_event_participant__update(
    integer, varchar, varchar, varchar, varchar,
	integer,
    boolean, varchar, varchar, varchar, varchar, boolean,
    integer, integer, integer, integer,
    integer, integer, integer
);
drop function flyhh_event_participant__new(
    integer,integer, integer, varchar, varchar, varchar, varchar,
	integer,
    boolean, varchar, varchar, varchar, varchar, boolean,
    integer, integer, integer, integer,
    integer, integer, integer
);

drop function flyhh_person_id_from_email_or_name(integer,varchar,varchar);
drop function flyhh_event_roommate__new(integer,integer,varchar,varchar);

drop table flyhh_event_roommates;
drop table flyhh_event_participants;

select flyhh__drop_type('flyhh_event_participant');
