<master>
<property name="title">@page_title;noquote@</property>
<property name="context">@page_title;noquote@</property>
<property name="main_navbar_label">participant</property>
<property name="left_navbar">@left_navbar_html;noquote@</property>
<property name="show_context_help">@show_context_help_p;noquote@</property>
@context_bar;noquote@
<br>
<br>

<if @new_request_p@ eq 1>
<div style="width:620px;">
    <formtemplate id="@form_id@"></formtemplate>
</div>
</if>
<else>
<table cellpadding="0" cellspacing="0" border="0" width="100%">
<tr>
  <td valign="top" width="50%">
<div style="width:620px;">
    <formtemplate id="@form_id@"></formtemplate>
</div>
    <%= [im_component_bay left] %>
  </td>
  <td width="2">&nbsp;</td>
  <td valign="top">
    <!-- Component Bay Right -->
    <%= [im_component_bay right] %>
    <!-- End Component Bay Right -->
  </td>
</tr>
</table>

<table cellpadding="0" cellspacing="0" border="0" width="100%">
<tr><td>
  <%= [im_component_bay bottom] %>
</td></tr>
</table>
</else>
