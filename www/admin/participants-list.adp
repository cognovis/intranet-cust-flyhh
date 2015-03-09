<master>
<property name="title">@page_title@</property>
<property name="context"></property>
<property name="main_navbar_label">#intranet-cust-flyhh.participants#</property>
<property name="left_navbar">@left_navbar_html;noquote@</property>
<property name="show_context_help">@show_context_help_p;noquote@</property>

<SCRIPT Language=JavaScript src=/resources/diagram/diagram/diagram.js></SCRIPT>

    @context_bar;noquote@
    <p>
    <a class="button" href="registration?project_id=@project_id@">#intranet-cust-flyhh.add_participant#</a>
    <p>
    <include src="/packages/intranet-cust-flyhh/lib/event-stats" event_id=@event_id@>
	<table class="table_list_page">
            @table_header_html;noquote@
            @table_body_html;noquote@ 
	</table>

