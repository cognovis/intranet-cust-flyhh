 <master src=@adp_master@>
 <if @error_text@ ne "">
 #intranet-cust-flyhh.lt_There_was_an_error_pr#
<p />
@error_text@
</if>
<else>
    <if @mail_body@ ne "">
        #intranet-cust-flyhh.lt_Your_mail_is_on_its_w#
    </if>
    <else>

        #intranet-cust-flyhh.lt_Please_provide_us_wit#
        <p />
        <div style="width:620px;">
            <formtemplate id="@form_id@"></formtemplate>
        </div>
    </else>
</else>



