-- @author Neophytos Demetriou
-- @creation-date 2014-10-15
-- @last-modified 2014-10-30

\i events-create.sql
\i participants-create.sql

-- Category IDs 82000-82999 reserved for Events

--
-- Flyhh - Event Registration Status
-- (status Options in the normal flow of things)
--

-- if the participant registers he is put onto a waiting list
SELECT im_category_new (82500, 'Waiting List', 'Flyhh - Event Registration Status');

-- this is the status we provide if the participant is accepted from our side into the camp
SELECT im_category_new (82501, 'Confirmed', 'Flyhh - Event Registration Status');

-- this is the status once the participant clicks the link to get the payment information
SELECT im_category_new (82502, 'Pending Payment', 'Flyhh - Event Registration Status');

-- this is the status once the participant has partially paid
SELECT im_category_new (82503, 'Partially Paid', 'Flyhh - Event Registration Status');

-- this is the status once the participant has fully paid
SELECT im_category_new (82504, 'Registered', 'Flyhh - Event Registration Status');

-- this is the status if the system kicks the partipanct out or we cancel the participant. 
-- This only happens if the participant is not registered yet
SELECT im_category_new (82505, 'Refused', 'Flyhh - Event Registration Status');

-- this is if the participant decided not to come anymore
SELECT im_category_new (82506, 'Cancelled', 'Flyhh - Event Registration Status');

--
-- Flyhh - Event Participant Level
--

SELECT im_category_new (82550, 'Beginner', 'Flyhh - Event Participant Level');
SELECT im_category_new (82551, 'Intermediate', 'Flyhh - Event Participant Level');
SELECT im_category_new (82552, 'Advanced', 'Flyhh - Event Participant Level');

-- im_biz_object__new is ill-defined in dump for flyhh, 
-- even though it is correct in intranet-biz-objects.sql (intranet-core)

create or replace function im_biz_object__new (integer,varchar,timestamptz,integer,varchar,integer)
returns integer as '
declare
        p_object_id     alias for $1;
        p_object_type   alias for $2;
        p_creation_date alias for $3;
        p_creation_user alias for $4;
        p_creation_ip   alias for $5;
        p_context_id    alias for $6;

        v_object_id     integer;
begin
        v_object_id := acs_object__new (
                p_object_id,
                p_object_type,
                p_creation_date,
                p_creation_user,
                p_creation_ip,
                p_context_id
        );
        insert into im_biz_objects (object_id) values (v_object_id);
        return v_object_id;

end;' language 'plpgsql';



-- auxiliary function for drop scripts
create or replace function flyhh__drop_type(varchar) returns boolean as '
declare
    p_object_type alias for $1;
begin

    delete from im_biz_objects where object_id in (select object_id from acs_objects where object_type=p_object_type);
    delete from acs_objects where object_type=p_object_type;
    delete from acs_object_type_tables where object_type=p_object_type;
    delete from im_dynfield_layout_pages where object_type=p_object_type;
    perform acs_object_type__drop_type(p_object_type,true);

    return true;

end;' language 'plpgsql';


