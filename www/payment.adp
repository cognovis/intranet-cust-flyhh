 <master src=@adp_master@>
  <if @error_text@ ne "">
  There was an error processing your request:
 <p />
 @error_text@
 </if>
 <else>
 <h2>Please find below your order with us:</h2>
 <table align=center width='80%' cellpadding=1 cellspacing=2 border=0>
 @invoice_item_html;noquote@
 <tr><td colspan=3>
 <br />
 <b>Please make your initial payment of at least @due_now_pretty@ @currency@ to our bank account within the next 3 days.</b>
 </td><tr>
 <tr><td colspan=2>
 <h2>Bank Info</h2>
 <td></td>
 </tr>
 <tr valign=top><td colspan=2>

     IBAN: DE64100100100822944102<br/>
     BIC (8-digits): PBNKDEFF<br/>
     BIC (11-digits): PBNKDEFF200<br/>
     Postbank Hamburg<br/>
     Transfer note: “@invoice_nr@ - @full_name@”<br/>
     </td><td>
     In case you need the bank's address:<br/>
     Ueberseering 26<br/>
     22297 Hamburg, Germany<br/>
 </td>
 </td></tr></table>
 <div align=center><B>Full payment of @total_due_pretty@ @currency@ is due August 1st 2015</b></div>
</else>