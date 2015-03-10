	<form action=/flyhh/roommates-action method=POST>
	<%= [export_form_vars return_url] %>
	<table class="table_list_page">
	<thead>	  
	  <tr class="rowtitle">
	    <td>&nbsp;</td>
	    <td><%= [::flyhh::mc Roommate "Roommate"] %></td>
	    <td><%= [::flyhh::mc Room "Room"] %></td>
	    <td><%= [::flyhh::mc Status "Status"] %></td>
	    	  </tr>
	</thead>	  
	<tbody>
	  <multiple name="roommates">
	    <if @roommates.rownum@ odd><tr class="roweven"></if>
	    <else><tr class="rowodd"></else>
		<td><input type=checkbox name=roommate.@roommates.roommate_person_id@></td>
		<td><a href="@roommates.roommate_url;noquote@">@roommates.roommate_name@</a></td>
        <td><a href="@roommates.room_url;noquote@">@roommates.room_name@</a></td>
        <td>@roommates.roommate_status;noquote@</td>
	    </tr>
	  </multiple>

<if @roommates:rowcount@ eq 0>
	<tr class="rowodd">
	    <td colspan=4>
		<%= [::flyhh::mc No_Roommates "No Roommates"] %>
	    </td>
	</tr>
</if>
	</tbody>
	</table>
	</form>