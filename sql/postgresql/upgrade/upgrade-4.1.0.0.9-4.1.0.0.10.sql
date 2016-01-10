select acs_log__debug('/packages/intranet-cust-flyhh/sql/postgresql/upgrade/upgrade-4.1.0.0.9-4.1.0.0.10.sql','');

create table flyhh_event_participant_level (
    participant_id      integer not null
                        primary key,
    self_level_id       integer
                        constraint flyhh_participants_level__level_fk
                        references im_categories(category_id),
    dance_location	varchar(250),
    dance_frequency_id  integer
			constraint flyhh_participants_level__dance_frequency_fk
                        references im_categories(category_id),
    dance_duration_id   integer
			constraint flyhh_participants_level__dance_duration_fk
                        references im_categories(category_id),
    dance_local_classes varchar(1000),
    dance_teaching	varchar(1000),
    international_workshops text,
    private_class	varchar(1000),
    other_dance_styles  text,
    primary_role_id     integer
			constraint flyhh_participants_level__primary_role_fk
                        references im_categories(category_id),
    border_level_type_id     integer
			constraint flyhh_participants_level__border_level_fk
                        references im_categories(category_id),
    competitions	text,
    level_references    text
);

-- Categories
SELECT im_category_new (82510, '0-1 times per month', 'Flyhh - Dance Frequency');
SELECT im_category_new (82511, '2-4 times per month', 'Flyhh - Dance Frequency');
SELECT im_category_new (82512, '1-2 times per week', 'Flyhh - Dance Frequency');
SELECT im_category_new (82513, '> 2 times per week', 'Flyhh - Dance Frequency');

SELECT im_category_new (82520, '0-6 months', 'Flyhh - Dance Duration');
SELECT im_category_new (82521, '6-12 months', 'Flyhh - Dance Duration');
SELECT im_category_new (82522, '1-2 years', 'Flyhh - Dance Duration');
SELECT im_category_new (82523, '2-3 years', 'Flyhh - Dance Duration');
SELECT im_category_new (82524, '3-4 years', 'Flyhh - Dance Duration');
SELECT im_category_new (82525, '> 4 years', 'Flyhh - Dance Duration');

SELECT im_category_new (82530, 'I only Follow', 'Flyhh - Primary Role');
SELECT im_category_new (82531, 'I mostly Follow', 'Flyhh - Primary Role');
SELECT im_category_new (82532, 'I dance both roles equally', 'Flyhh - Primary Role');
SELECT im_category_new (82533, 'I mostly lead', 'Flyhh - Primary Role');
SELECT im_category_new (82534, 'I only lead', 'Flyhh - Primary Role');

SELECT im_category_new (82540, 'I like to be pushed hard', 'Flyhh - Border Level');
SELECT im_category_new (82541, 'I would prefer to dance in my own pace', 'Flyhh - Border Level');
