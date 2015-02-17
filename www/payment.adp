 <master src=@adp_master@>
  <if @error_text@ ne "">
  There was an error processing your request:
 <p />
 @error_text@
 </if>
 <else>
<a href="@invoice_pdf_link@">invoice pdf</a>

</else>