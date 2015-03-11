<master>
<property name="title">@page_title;noquote@</property>
<property name="context">@context;noquote@</property>
<property name="left_navbar">@left_navbar_html;noquote@</property>

@context_bar;noquote@

<table>
    <tr valign="top">
        <td><formtemplate id="@form_id@"></formtemplate></td>
        <if @filter_project_id@ ne "">
        <td>
            <include src="/packages/intranet-cust-flyhh/lib/room-occupants" project_id=@filter_project_id@ room_id=@room_id@>            
        </td>
        </if>
    </tr>
</table>
