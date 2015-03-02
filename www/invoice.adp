 <master src=@adp_master@>
  <if @error_text@ ne "">
  #intranet-cust-flyhh.lt_There_was_an_error_pr#
 <p />
 @error_text@
 </if>
 <else>
 <h2>#intranet-cust-flyhh.lt_Please_find_below_you#</h2>
 <table align=center width='80%' cellpadding=1 cellspacing=2 border=0>
 @invoice_item_html;noquote@
 <tr><td colspan=3>
 <br />
<if @due_now@ gt 0>
 <b>#intranet-cust-flyhh.lt_Please_make_your_init#</b>
</if>
<if @paid_amount@ gt 0>
<b>We have received payment of @paid_amount_pretty;noquote@ @currency@ so far.</b>
 </td><tr>
 <tr><td colspan=2>
 <h2>#intranet-cust-flyhh.Bank_Info#</h2>
 <td></td>
 </tr>
 <tr valign=top><td colspan=2>

     IBAN: DE64100100100822944102<br/>
     BIC (8-digits): PBNKDEFF<br/>
     BIC (11-digits): PBNKDEFF200<br/>
     Postbank Hamburg<br/>
     #intranet-cust-flyhh.lt_Transfer_note_invoice#<br/>
     </td><td>
     #intranet-cust-flyhh.lt_In_case_you_need_the_#<br/>
     Ueberseering 26<br/>
     22297 Hamburg, Germany<br/>
 </td>
 </td></tr></table>
 <div align=center><B>#intranet-cust-flyhh.lt_Full_payment_of_total#</b></div>
</else>
