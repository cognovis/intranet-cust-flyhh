<master>
<property name="title">@page_title@</property>
<property name="context"></property>
<property name="main_navbar_label">#intranet-cust-flyhh.Rooms#</property>
<property name="left_navbar">@left_navbar_html;noquote@</property>
<property name="show_context_help">@show_context_help_p;noquote@</property>
<include src="/packages/intranet-cust-flyhh/lib/room-stats">
<p />
<listtemplate name="rooms_list"></listtemplate>
<listtemplate name="room_occupation"></listtemplate>
<form action='/flyhh/admin/room-one' method="get">
<input type="hidden" name="return_url" value="/flyhh/admin/rooms-list">
<input type="submit" value="New Room">
</form>