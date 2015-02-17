 <master src=@adp_master@>
 <if @error_text@ ne "">
 There was an error processing your request:
<p />
@error_text@
</if>
<else>
    <if @mail_body@ ne "">
        Your mail is on its way!
    </if>
    <else>

        Please provide us with your first and lastname and click submit to receive your registration link via E-Mail
        <p />
        <div style="width:620px;">
            <formtemplate id="@form_id@"></formtemplate>
        </div>
    </else>
</else>


