<master>
<property name="title">@page_title@</property>
<property name="context"></property>
<property name="main_navbar_label">participants</property>
<property name="left_navbar">@left_navbar_html;noquote@</property>
<property name="show_context_help">@show_context_help_p;noquote@</property>

<SCRIPT Language=JavaScript src=/resources/diagram/diagram/diagram.js></SCRIPT>

    @context_bar;noquote@
    <p>
    <a class="button" href="../registration?project_id=@project_id@">add participant</a>
    <p>
	<table class="table_list_page">
            @table_header_html;noquote@
            @table_body_html;noquote@ 
	</table>
