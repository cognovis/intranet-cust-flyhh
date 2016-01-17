select acs_log__debug('/packages/intranet-cust-flyhh/sql/postgresql/upgrade/upgrade-4.1.0.0.11-4.1.0.0.12.sql','');


-- Logging Table for mails send to participants
create table flyhh_event_participant_invitation (
    email   varchar not null,
    event_id    integer not null
                constraint flyhh_ep_inviation__event_fk
            references flyhh_events(event_id),
    mail_log_id integer
                constraint flyhh_ep_inviation__mail_fk
                references acs_mail_log(log_id)
);
