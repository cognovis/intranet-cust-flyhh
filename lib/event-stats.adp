<p>#intranet-cust-flyhh.lt_Viewing_stats_for_eve# <a href="event-one?event_id=@event_id@">@event_name@</a>

<table>
<tr valign=top>
<td>
<table class="list-table" cellpadding="3" cellspacing="1">
@table_header_html;noquote@
@table_body_html;noquote@
</table>    
</td>
<td>
    <listtemplate name="@list_id@"></listtemplate>
<p />
<table class="list-table" cellpadding="3" cellspacing="1">
@table_checks_html;noquote@
</table>
<p />
<include src="/packages/intranet-cust-flyhh/lib/level-stats" event_id=@event_id@></td>
</tr>
<tr>
<td colspan=2>
<table class="list-table" cellpadding="3" cellspacing="1">
@table_header_html;noquote@
@bus_body_html;noquote@
</td>
</tr>
</table>
</p>