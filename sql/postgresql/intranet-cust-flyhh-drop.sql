-- @author Neophytos Demetriou
-- @creation-date 2014-10-30
-- @last-modified 2014-10-30

\i participants-drop.sql
\i events-drop.sql

delete from im_categories where category_id in (82500,82501,82502,82503,82504,82505,82506,82510,82511,82512,82513,82514,82515,82516,82517,82518,82550,82551,82552);

drop function flyhh__drop_type(varchar);

