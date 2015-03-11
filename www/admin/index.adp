<master>
<property name="title">@page_title;noquote@</property>
<property name="context">@context;noquote@</property>

@context_bar;noquote@
<p>
<div>
    <a class="button" href="event-one">#intranet-cust-flyhh.Add_Event#</a>
    <a class="button" href="rooms-list">#intranet-cust-flyhh.Rooms#</a>
</div>
<br>
<br>
<listtemplate name="@list_id@"></listtemplate>
<multiple name="events">
    <include src="/packages/intranet-cust-flyhh/lib/event-stats" event_id=@events.event_id@>
</multiple>
<br>
<br>
#intranet-cust-flyhh.Provider_Company# <a href="@provider_company_link@">@provider_company_name@</a>
