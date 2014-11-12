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

create or replace function im_biz_object__new (
    p_object_id     integer,
    p_object_type   varchar,
    p_creation_date timestamptz,
    p_creation_user integer,
    p_creation_ip   varchar,
    p_context_id    integer
) returns integer as 
$$
declare
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

end;
$$ language 'plpgsql';



-- auxiliary function for drop scripts
create or replace function flyhh__drop_type(p_object_type varchar) 
returns boolean as 
$$
begin

    delete from im_biz_objects where object_id in (select object_id from acs_objects where object_type=p_object_type);
    delete from acs_objects where object_type=p_object_type;
    delete from acs_object_type_tables where object_type=p_object_type;
    delete from im_dynfield_layout_pages where object_type=p_object_type;
    perform acs_object_type__drop_type(p_object_type,true);

    return true;

end;
$$ language 'plpgsql';

create or replace function flyhh__im_payment_after_insert_tr()
returns trigger as
$$
declare
    v_record        record;
    v_vat_amount  numeric(12,2);
    v_status_id     integer;
begin

    select cst.cost_id, cst.cost_status_id, cst.amount, cst.paid_amount, participant_id into v_record
    from im_costs cst 
    inner join im_payments pay on (pay.cost_id=cst.cost_id)
    inner join flyhh_event_participants reg on (reg.company_id = cst.customer_id and reg.project_id = cst.project_id)
    where payment_id = new.payment_id;

    if found then

       select sum(round(item_units*price_per_unit*cb.aux_int1/100,2))
         into v_vat_amount
         from im_invoice_items ii, im_categories ca, im_categories cb, im_materials im 
        where invoice_id = v_record.cost_id
          and ca.category_id = material_type_id
          and ii.item_material_id = im.material_id
          and ca.aux_int2 = cb.category_id; 

        -- cost status: paid (=3810)
        -- cost status: partially paid (=3808)
        -- event registration status: registered (=82504)
        -- event registration status: partially paid (=82503)

        if v_record.amount + v_vat_amount = v_record.paid_amount + new.amount then
            v_status_id = 82504;
        else
            v_status_id = 82503;
        end if;

        update flyhh_event_participants 
        set event_participant_status_id=v_status_id 
        where participant_id=v_record.participant_id; 

    end if;

    return new;

end;
$$ language 'plpgsql';

-- For a product like project-open, triggers make it really hard for developers 
-- to understand why values change after submitting something on the page, 
-- as you usually only check the source code and callbacks but not open PSQL and do 
-- queries on the database table to find out which triggers are installed.
--
-- create trigger flyhh__im_payment_after_insert_tr
-- after insert on im_payments
-- for each row
-- execute procedure flyhh__im_payment_after_insert_tr();
