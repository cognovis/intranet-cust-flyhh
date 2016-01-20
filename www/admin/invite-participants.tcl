ad_page_contract {
    Invite Participants to Events
} {
}

# Get the current event_options
set event_options [list]
db_foreach events "select event_id as option_event_id,event_name as event_name from flyhh_events e, im_projects p where e.project_id = p.project_id and p.project_status_id = [im_project_status_open] order by event_name" {
    lappend event_options [list $event_name $option_event_id]
}

set content "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\">
<html xmlns=\"http://www.w3.org/1999/xhtml\">
	<head>
	 <!-- NAME: 1 COLUMN -->
		<meta http-equiv=\"Content-Type\" content=\"text/html; charset=UTF-8\">
		<meta name=\"viewport\" content=\"width=device-width  initial-scale=1.0\">
		<title>anmelden!</title>

	<style type=\"text/css\">
  body #bodyTable #bodyCell{
   height:100% !important;
   margin:0;
   padding:0;
   width:100% !important;
  }
  table{
   border-collapse:collapse;
  }
  img a img{
   border:0;
   outline:none;
   text-decoration:none;
  }
  h1 h2 h3 h4 h5 h6{
   margin:0;
   padding:0;
  }
  p{
   margin:1em 0;
   padding:0;
  }
  a{
   word-wrap:break-word;
  }
  .ReadMsgBody{
   width:100%;
  }
  .ExternalClass{
   width:100%;
  }
  .ExternalClass .ExternalClass p .ExternalClass span .ExternalClass font .ExternalClass td .ExternalClass div{
   line-height:100%;
  }
  table td{
   mso-table-lspace:0pt;
   mso-table-rspace:0pt;
  }
  #outlook a{
   padding:0;
  }
  img{
   -ms-interpolation-mode:bicubic;
  }
  body table td p a li blockquote{
   -ms-text-size-adjust:100%;
   -webkit-text-size-adjust:100%;
  }
  #templatePreheader #templateHeader #templateBody #templateFooter{
   min-width:100%;
  }
  #bodyCell{
   padding:20px;
  }
  .mcnImage{
   vertical-align:bottom;
  }
  .mcnTextContent img{
   height:auto !important;
  }
  body #bodyTable{
   background-color:#F2F2F2;
  }
  #bodyCell{
   border-top:0;
  }
  #templateContainer{
   border:0;
  }
  h1{
   color:#606060 !important;
   display:block;
   font-family:Helvetica;
   font-size:40px;
   font-style:normal;
   font-weight:bold;
   line-height:125%;
   letter-spacing:-1px;
   margin:0;
   text-align:left;
  }
  h2{
   color:#404040 !important;
   display:block;
   font-family:Helvetica;
   font-size:26px;
   font-style:normal;
   font-weight:bold;
   line-height:125%;
   letter-spacing:-.75px;
   margin:0;
   text-align:left;
  }
  h3{
   color:#606060 !important;
   display:block;
   font-family:Helvetica;
   font-size:18px;
   font-style:normal;
   font-weight:bold;
   line-height:125%;
   letter-spacing:-.5px;
   margin:0;
   text-align:left;
  }
  h4{
   color:#808080 !important;
   display:block;
   font-family:Helvetica;
   font-size:16px;
   font-style:normal;
   font-weight:bold;
   line-height:125%;
   letter-spacing:normal;
   margin:0;
   text-align:left;
  }
  #templatePreheader{
   background-color:#FFFFFF;
   border-top:0;
   border-bottom:0;
  }
  .preheaderContainer .mcnTextContent .preheaderContainer .mcnTextContent p{
   color:#606060;
   font-family:Helvetica;
   font-size:11px;
   line-height:125%;
   text-align:left;
  }
  .preheaderContainer .mcnTextContent a{
   color:#606060;
   font-weight:normal;
   text-decoration:underline;
  }
  #templateHeader{
   background-color:#FFFFFF;
   border-top:0;
   border-bottom:0;
  }
  .headerContainer .mcnTextContent .headerContainer .mcnTextContent p{
   color:#606060;
   font-family:Helvetica;
   font-size:15px;
   line-height:150%;
   text-align:left;
  }
  .headerContainer .mcnTextContent a{
   color:#6DC6DD;
   font-weight:normal;
   text-decoration:underline;
  }
  #templateBody{
   background-color:#FFFFFF;
   border-top:0;
   border-bottom:0;
  }
  .bodyContainer .mcnTextContent .bodyContainer .mcnTextContent p{
   color:#606060;
   font-family:Helvetica;
   font-size:15px;
   line-height:150%;
   text-align:left;
  }
  .bodyContainer .mcnTextContent a{
   color:#6DC6DD;
   font-weight:normal;
   text-decoration:underline;
  }
  #templateFooter{
   background-color:#FFFFFF;
   border-top:0;
   border-bottom:0;
  }
  .footerContainer .mcnTextContent .footerContainer .mcnTextContent p{
   color:#606060;
   font-family:Helvetica;
   font-size:11px;
   line-height:125%;
   text-align:left;
  }
  .footerContainer .mcnTextContent a{
   color:#606060;
   font-weight:normal;
   text-decoration:underline;
  }
 @media only screen and (max-width: 480px){
  body table td p a li blockquote{
   -webkit-text-size-adjust:none !important;
  }

} @media only screen and (max-width: 480px){
  body{
   width:100% !important;
   min-width:100% !important;
  }

} @media only screen and (max-width: 480px){
  td\[id=bodyCell]{
   padding:10px !important;
  }

} @media only screen and (max-width: 480px){
  table\[class=mcnTextContentContainer]{
   width:100% !important;
  }

} @media only screen and (max-width: 480px){
  .mcnBoxedTextContentContainer{
   max-width:100% !important;
   min-width:100% !important;
   width:100% !important;
  }

} @media only screen and (max-width: 480px){
  table\[class=mcpreview-image-uploader]{
   width:100% !important;
   display:none !important;
  }

} @media only screen and (max-width: 480px){
  img\[class=mcnImage]{
   width:100% !important;
  }

} @media only screen and (max-width: 480px){
  table\[class=mcnImageGroupContentContainer]{
   width:100% !important;
  }

} @media only screen and (max-width: 480px){
  td\[class=mcnImageGroupContent]{
   padding:9px !important;
  }

} @media only screen and (max-width: 480px){
  td\[class=mcnImageGroupBlockInner]{
   padding-bottom:0 !important;
   padding-top:0 !important;
  }

} @media only screen and (max-width: 480px){
  tbody\[class=mcnImageGroupBlockOuter]{
   padding-bottom:9px !important;
   padding-top:9px !important;
  }

} @media only screen and (max-width: 480px){
  table\[class=mcnCaptionTopContent] table\[class=mcnCaptionBottomContent]{
   width:100% !important;
  }

} @media only screen and (max-width: 480px){
  table\[class=mcnCaptionLeftTextContentContainer] table\[classmcnCaptionRightTextContentContainer] table\[class=mcnCaptionLeftImageContentContainer] table\[class=mcnCaptionRightImageContentContainer] table\[class=mcnImageCardLeftTextContentContainer] table\[class=mcnImageCardRightTextContentContainer]{
   width:100% !important;
  }

} @media only screen and (max-width: 480px){
  td\[class=mcnImageCardLeftImageContent] td\[class=mcnImageCardRightImageContent]{
   padding-right:18px !important;
   padding-left:18px !important;
   padding-bottom:0 !important;
  }

} @media only screen and (max-width: 480px){
  td\[class=mcnImageCardBottomImageContent]{
   padding-bottom:9px !important;
  }

} @media only screen and (max-width: 480px){
  td\[class=mcnImageCardTopImageContent]{
   padding-top:18px !important;
  }

} @media only screen and (max-width: 480px){
  td\[class=mcnImageCardLeftImageContent] td\[class=mcnImageCardRightImageContent]{
   padding-right:18px !important;
   padding-left:18px !important;
   padding-bottom:0 !important;
  }

} @media only screen and (max-width: 480px){
  td\[class=mcnImageCardBottomImageContent]{
   padding-bottom:9px !important;
  }

} @media only screen and (max-width: 480px){
  td\[class=mcnImageCardTopImageContent]{
   padding-top:18px !important;
  }

} @media only screen and (max-width: 480px){
  table\[class=mcnCaptionLeftContentOuter] td\[class=mcnTextContent] table\[class=mcnCaptionRightContentOuter] td\[class=mcnTextContent]{
   padding-top:9px !important;
  }

} @media only screen and (max-width: 480px){
  td\[class=mcnCaptionBlockInner] table\[class=mcnCaptionTopContent]:last-child td\[class=mcnTextContent]{
   padding-top:18px !important;
  }

} @media only screen and (max-width: 480px){
  td\[class=mcnBoxedTextContentColumn]{
   padding-left:18px !important;
   padding-right:18px !important;
  }

} @media only screen and (max-width: 480px){
  td\[class=mcnTextContent]{
   padding-right:18px !important;
   padding-left:18px !important;
  }

} @media only screen and (max-width: 480px){
  table\[id=templateContainer] table\[id=templatePreheader] table\[id=templateHeader] table\[id=templateBody] table\[id=templateFooter]{
   max-width:600px !important;
   width:100% !important;
  }

} @media only screen and (max-width: 480px){
  h1{
   font-size:24px !important;
   line-height:125% !important;
  }

} @media only screen and (max-width: 480px){
  h2{
   font-size:20px !important;
   line-height:125% !important;
  }

} @media only screen and (max-width: 480px){
  h3{
   font-size:18px !important;
   line-height:125% !important;
  }

} @media only screen and (max-width: 480px){
  h4{
   font-size:16px !important;
   line-height:125% !important;
  }

} @media only screen and (max-width: 480px){
  table\[class=mcnBoxedTextContentContainer] td\[class=mcnTextContent] td\[class=mcnBoxedTextContentContainer] td\[class=mcnTextContent] p{
   font-size:18px !important;
   line-height:125% !important;
  }

} @media only screen and (max-width: 480px){
  table\[id=templatePreheader]{
   display:block !important;
  }

} @media only screen and (max-width: 480px){
  td\[class=preheaderContainer] td\[class=mcnTextContent] td\[class=preheaderContainer] td\[class=mcnTextContent] p{
   font-size:14px !important;
   line-height:115% !important;
  }

} @media only screen and (max-width: 480px){
  td\[class=headerContainer] td\[class=mcnTextContent] td\[class=headerContainer] td\[class=mcnTextContent] p{
   font-size:18px !important;
   line-height:125% !important;
  }

} @media only screen and (max-width: 480px){
  td\[class=bodyContainer] td\[class=mcnTextContent] td\[class=bodyContainer] td\[class=mcnTextContent] p{
   font-size:18px !important;
   line-height:125% !important;
  }

} @media only screen and (max-width: 480px){
  td\[class=footerContainer] td\[class=mcnTextContent] td\[class=footerContainer] td\[class=mcnTextContent] p{
   font-size:14px !important;
   line-height:115% !important;
  }

} @media only screen and (max-width: 480px){
  td\[class=footerContainer] a\[class=utilityLink]{
   display:block !important;
  }

}</style></head>
	<body leftmargin=\"0\" marginwidth=\"0\" topmargin=\"0\" marginheight=\"0\" offset=\"0\" style=\"margin: 0;padding: 0;-ms-text-size-adjust: 100%;-webkit-text-size-adjust: 100%;background-color: #F2F2F2;height: 100% !important;width: 100% !important;\">
		<center>
			<table align=\"center\" border=\"0\" cellpadding=\"0\" cellspacing=\"0\" height=\"100%\" width=\"100%\" id=\"bodyTable\" style=\"border-collapse: collapse;mso-table-lspace: 0pt;mso-table-rspace: 0pt;-ms-text-size-adjust: 100%;-webkit-text-size-adjust: 100%;margin: 0;padding: 0;background-color: #F2F2F2;height: 100% !important;width: 100% !important;\">
				<tr>
					<td align=\"center\" valign=\"top\" id=\"bodyCell\" style=\"mso-table-lspace: 0pt;mso-table-rspace: 0pt;-ms-text-size-adjust: 100%;-webkit-text-size-adjust: 100%;margin: 0;padding: 20px;border-top: 0;height: 100% !important;width: 100% !important;\">
						<!-- BEGIN TEMPLATE // -->
						<table border=\"0\" cellpadding=\"0\" cellspacing=\"0\" width=\"600\" id=\"templateContainer\" style=\"border-collapse: collapse;mso-table-lspace: 0pt;mso-table-rspace: 0pt;-ms-text-size-adjust: 100%;-webkit-text-size-adjust: 100%;border: 0;\">
							<tr>
								<td align=\"center\" valign=\"top\" style=\"mso-table-lspace: 0pt;mso-table-rspace: 0pt;-ms-text-size-adjust: 100%;-webkit-text-size-adjust: 100%;\">
									<!-- BEGIN HEADER // -->
									<table border=\"0\" cellpadding=\"0\" cellspacing=\"0\" width=\"600\" id=\"templateHeader\" style=\"border-collapse: collapse;mso-table-lspace: 0pt;mso-table-rspace: 0pt;-ms-text-size-adjust: 100%;-webkit-text-size-adjust: 100%;min-width: 100%;background-color: #FFFFFF;border-top: 0;border-bottom: 0;\">
										<tr>
											<td valign=\"top\" class=\"headerContainer\" style=\"mso-table-lspace: 0pt;mso-table-rspace: 0pt;-ms-text-size-adjust: 100%;-webkit-text-size-adjust: 100%;\"><table border=\"0\" cellpadding=\"0\" cellspacing=\"0\" width=\"100%\" class=\"mcnImageBlock\" style=\"min-width: 100%;border-collapse: collapse;mso-table-lspace: 0pt;mso-table-rspace: 0pt;-ms-text-size-adjust: 100%;-webkit-text-size-adjust: 100%;\">
	<tbody class=\"mcnImageBlockOuter\">
			<tr>
				<td valign=\"top\" style=\"padding: 9px;mso-table-lspace: 0pt;mso-table-rspace: 0pt;-ms-text-size-adjust: 100%;-webkit-text-size-adjust: 100%;\" class=\"mcnImageBlockInner\">
					<table align=\"left\" width=\"100%\" border=\"0\" cellpadding=\"0\" cellspacing=\"0\" class=\"mcnImageContentContainer\" style=\"min-width: 100%;border-collapse: collapse;mso-table-lspace: 0pt;mso-table-rspace: 0pt;-ms-text-size-adjust: 100%;-webkit-text-size-adjust: 100%;\">
						<tbody><tr>
							<td class=\"mcnImageContent\" valign=\"top\" style=\"padding-right: 9px;padding-left: 9px;padding-top: 0;padding-bottom: 0;text-align: center;mso-table-lspace: 0pt;mso-table-rspace: 0pt;-ms-text-size-adjust: 100%;-webkit-text-size-adjust: 100%;\">


										<img align=\"center\" alt=\"EVENT IMAGE\" src=\"@event_image_url;noquote@\" width=\"564\" style=\"max-width: 1024px;padding-bottom: 0;display: inline !important;vertical-align: bottom;border: 0;outline: none;text-decoration: none;-ms-interpolation-mode: bicubic;\" class=\"mcnImage\">


							</td>
						</tr>
					</tbody></table>
				</td>
			</tr>
	</tbody>
</table></td>
										</tr>
									</table>
									<!-- // END HEADER -->
								</td>
							</tr>
							<tr>
								<td align=\"center\" valign=\"top\" style=\"mso-table-lspace: 0pt;mso-table-rspace: 0pt;-ms-text-size-adjust: 100%;-webkit-text-size-adjust: 100%;\">
									<!-- BEGIN BODY // -->
									<table border=\"0\" cellpadding=\"0\" cellspacing=\"0\" width=\"600\" id=\"templateBody\" style=\"border-collapse: collapse;mso-table-lspace: 0pt;mso-table-rspace: 0pt;-ms-text-size-adjust: 100%;-webkit-text-size-adjust: 100%;min-width: 100%;background-color: #FFFFFF;border-top: 0;border-bottom: 0;\">
										<tr>
											<td valign=\"top\" class=\"bodyContainer\" style=\"mso-table-lspace: 0pt;mso-table-rspace: 0pt;-ms-text-size-adjust: 100%;-webkit-text-size-adjust: 100%;\"><table border=\"0\" cellpadding=\"0\" cellspacing=\"0\" width=\"100%\" class=\"mcnTextBlock\" style=\"min-width: 100%;border-collapse: collapse;mso-table-lspace: 0pt;mso-table-rspace: 0pt;-ms-text-size-adjust: 100%;-webkit-text-size-adjust: 100%;\">
	<tbody class=\"mcnTextBlockOuter\">
		<tr>
			<td valign=\"top\" class=\"mcnTextBlockInner\" style=\"mso-table-lspace: 0pt;mso-table-rspace: 0pt;-ms-text-size-adjust: 100%;-webkit-text-size-adjust: 100%;\">

				<table align=\"left\" border=\"0\" cellpadding=\"0\" cellspacing=\"0\" width=\"100%\" style=\"min-width: 100%;border-collapse: collapse;mso-table-lspace: 0pt;mso-table-rspace: 0pt;-ms-text-size-adjust: 100%;-webkit-text-size-adjust: 100%;\" class=\"mcnTextContentContainer\">
					<tbody><tr>

						<td valign=\"top\" class=\"mcnTextContent\" style=\"padding-top: 9px;padding-right: 18px;padding-bottom: 9px;padding-left: 18px;mso-table-lspace: 0pt;mso-table-rspace: 0pt;-ms-text-size-adjust: 100%;-webkit-text-size-adjust: 100%;color: #606060;font-family: Helvetica;font-size: 15px;line-height: 150%;text-align: left;\">

							<div style=\"text-align: justify;\">
<div style=\"color: #606060;font-family: Helvetica;font-size: 15px;\">
<div><span style=\"font-family:tahoma verdana segoe sans-serif\"><span style=\"font-size:11px\"><strong>@salutation;noquote@</strong></span></span><br>
&nbsp;</div>

<div style=\"text-align: justify;\"><span style=\"font-family:tahoma verdana segoe sans-serif\"><span style=\"font-size:11px\">Registration for @event_name;noquote@</span></span><span style=\"font-family:tahoma verdana segoe sans-serif; font-size:11px\">&nbsp;just&nbsp;</span><span style=\"font-family:tahoma verdana segoe sans-serif\"><span style=\"font-size:11px\">started - and here's your personal link to register:</span>
<p>
<a href='@registration_url;noquote@'>Sign me up!</a>
</p>
@date_website;noquote@
<br>
<span style=\"font-family:tahoma verdana segoe sans-serif\"><span style=\"font-size:11px\">And if you want to know how it feels like - here's a beautiful&nbsp;<a href=\"https://vimeo.com/151409171\" target=\"_blank\" style=\"word-wrap: break-word;-ms-text-size-adjust: 100%;-webkit-text-size-adjust: 100%;color: #6DC6DD;font-weight: normal;text-decoration: underline;\">video</a>&nbsp;of last year's edition.<br>
<br>
See you in September - we can't wait!<br>
Anna &amp; Malte</span></span></div>
</div>
</div>

						</td>
					</tr>
				</tbody></table>

			</td>
		</tr>
	</tbody>
</table><table border=\"0\" cellpadding=\"0\" cellspacing=\"0\" width=\"100%\" class=\"mcnImageBlock\" style=\"min-width: 100%;border-collapse: collapse;mso-table-lspace: 0pt;mso-table-rspace: 0pt;-ms-text-size-adjust: 100%;-webkit-text-size-adjust: 100%;\">
	<tbody class=\"mcnImageBlockOuter\">
			<tr>
				<td valign=\"top\" style=\"padding: 9px;mso-table-lspace: 0pt;mso-table-rspace: 0pt;-ms-text-size-adjust: 100%;-webkit-text-size-adjust: 100%;\" class=\"mcnImageBlockInner\">
					<table align=\"left\" width=\"100%\" border=\"0\" cellpadding=\"0\" cellspacing=\"0\" class=\"mcnImageContentContainer\" style=\"min-width: 100%;border-collapse: collapse;mso-table-lspace: 0pt;mso-table-rspace: 0pt;-ms-text-size-adjust: 100%;-webkit-text-size-adjust: 100%;\">
						<tbody><tr>
							<td class=\"mcnImageContent\" valign=\"top\" style=\"padding-right: 9px;padding-left: 9px;padding-top: 0;padding-bottom: 0;text-align: center;mso-table-lspace: 0pt;mso-table-rspace: 0pt;-ms-text-size-adjust: 100%;-webkit-text-size-adjust: 100%;\">


										<img align=\"center\" alt=\"\" src=\"http://www.swingcastlecamp.de/wp-content/uploads/2015/11/castlesilhouetteGIGAtransparent-624x259.png\" width=\"564\" style=\"max-width: 664px;padding-bottom: 0;display: inline !important;vertical-align: bottom;border: 0;outline: none;text-decoration: none;-ms-interpolation-mode: bicubic;\" class=\"mcnImage\">


							</td>
						</tr>
					</tbody></table>
				</td>
			</tr>
	</tbody>
</table></td>
										</tr>
									</table>
									<!-- // END BODY -->
								</td>
							</tr>
							<tr>
								<td align=\"center\" valign=\"top\" style=\"mso-table-lspace: 0pt;mso-table-rspace: 0pt;-ms-text-size-adjust: 100%;-webkit-text-size-adjust: 100%;\">
								</td>
							</tr>
						</table>
						<!-- // END TEMPLATE -->
					</td>
				</tr>
				<tr>
					<td align=\"center\" valign=\"top\" style=\"padding-top:20px; padding-bottom:20px;\">
						<table border=\"0\" cellpadding=\"0\" cellspacing=\"0\" id=\"canspamBar\">
							<tr>
								<td align=\"center\" valign=\"top\" style=\"color:#606060; font-family:Helvetica  Arial  sans-serif; font-size:11px; line-height:150%; padding-right:20px; padding-bottom:5px; padding-left:20px; text-align:center;\">
									This email was sent to <a href=\"mailto:@email;noquote@\" target=\"_blank\" style=\"color:#404040 !important;\">@email;noquote@</a>
									<br />
									<br />
									Flying Hamburger Events &middot; Schrödersweg 27 &middot; Hamburg 22453 &middot; Germany
								</td>
							</tr>
						</table>
					</td>
				</tr>
			</table>
		</center>
</body>
</html>"



set mime_type "text/html"
set content_list [list $content $mime_type]

set form_id "invite_participants"
set action_url "invite-participants"
ad_form \
    -name $form_id \
    -html { enctype multipart/form-data } \
    -action $action_url \
    -form {
		{event_id:text(select)
		    {label "[_ intranet-cust-flyhh.Events]:"} 
		    {options  $event_options }
		}
		{to_addr:text(text),optional
		    {label "[_ acs-mail-lite.Recipients]:"} 
		    {html {size 56}}
		    {help_text "[_ acs-mail-lite.cc_help]"}
		}
		{to_csv:file(file),optional
			{label "CSV with E-Mails"}
		}
		{subject:text(text)
		    {label "[_ acs-mail-lite.Subject]"}
		    {html {size 55}}
		    {value "Register for @event_name;noquote@"}
		}
		{content_body:text(richtext),optional
		    {label "[_ acs-mail-lite.Message]"}
		    {html {cols 100 rows 90}}
		    {value $content_list}
		}
    } -on_submit {
        set to_addr [split $to_addr ";"]
		set to_addr [lsort -unique $to_addr]
		db_1row context "select project_id as context_id, event_email,event_name from flyhh_events where event_id = :event_id" 
		if {$event_name eq "Swing Castle Camp 2016"} {
			set event_image_url "http://www.swingcastlecamp.de/wp-content/uploads/2015/11/banner16-624x130.png"
			set default_salutation "Dear Swing Addicts!"
		    set date_website "<span style=\"font-family:tahoma verdana segoe sans-serif\"><span style=\"font-size:11px\">The new version will happen from&nbsp;</span></span><span style=\"font-family:tahoma verdana segoe sans-serif\"><span style=\"font-size:11px\">S</span></span><span style=\"font-family:tahoma verdana segoe sans-serif; font-size:11px\">eptember&nbsp;23rd till 29th.&nbsp;</span><span style=\"font-family:tahoma verdana segoe sans-serif\"><span style=\"font-size:11px\">If you need some more&nbsp;information:<br>
Please check the&nbsp;</span></span><a href=\"http://www.swingcastlecamp.de/\" style=\"font-family: tahoma  verdana  segoe  sans-serif;font-size: 11px;text-align: justify;word-wrap: break-word;color: #6DC6DD;-ms-text-size-adjust: 100%;-webkit-text-size-adjust: 100%;font-weight: normal;text-decoration: underline;\" target=\"_blank\">website</a>.<br>"

		} else {
			set event_image_url "http://www.balboacastlecamp.de/wp-content/uploads/2015/11/fb_banner_bcc-624x131.png"
			set default_salutation "Dear Balboa Addicts!"
		    set date_website "<span style=\"font-family:tahoma verdana segoe sans-serif\"><span style=\"font-size:11px\">The new version will happen from&nbsp;</span></span><span style=\"font-family:tahoma verdana segoe sans-serif\"><span style=\"font-size:11px\">S</span></span><span style=\"font-family:tahoma verdana segoe sans-serif; font-size:11px\">eptember&nbsp;16th till 23rd.&nbsp;</span><span style=\"font-family:tahoma verdana segoe sans-serif\"><span style=\"font-size:11px\">If you need some more&nbsp;information:<br>
Please check the&nbsp;</span></span><a href=\"http://www.balboacastlecamp.de/\" style=\"font-family: tahoma  verdana  segoe  sans-serif;font-size: 11px;text-align: justify;word-wrap: break-word;color: #6DC6DD;-ms-text-size-adjust: 100%;-webkit-text-size-adjust: 100%;font-weight: normal;text-decoration: underline;\" target=\"_blank\">website</a>.<br><span style=\"font-family:tahoma verdana segoe sans-serif\"><span style=\"font-size:11px\"><br />This time you can also stay longer and join us for the weekend of the <a href='http://www.swingcastlecamp.de/'>Swing Castle Camp</a> with a dedicated Balboa dancefloor.</span><br />"
		}
		
		# Search for E-Mails in the CSV
		# Only in the first column
		if {[exists_and_not_null to_csv]} {
			set tmp_filename [template::util::file::get_property tmp_filename $to_csv]
			set csv_files_content [fileutil::cat $tmp_filename]
			set csv_files [split $csv_files_content "\n"]
			set csv_files_len [llength $csv_files]
			
			set separator [im_csv_guess_separator $csv_files]
			
			# Split the header into its fields
			set csv_header [string trim [lindex $csv_files 0]]
			set csv_header_fields [im_csv_split $csv_header $separator]
			set csv_header_len [llength $csv_header_fields]
			set values_list_of_lists [im_csv_get_values $csv_files_content $separator]
			foreach csv_line_fields $values_list_of_lists {
				set email [lindex $csv_line_fields 0]
				if {[acs_mail_lite::utils::valid_email_p $email]} {
					lappend to_addr $email
				}

			}
		}
		
		foreach email $to_addr {
		    set link_html ""
		    set email [string trim $email]
		    
			# send the E-mail (if not already send)
			set already_invited_p [db_string already_invited "select 1 from flyhh_event_participant_invitation where email = :email and event_id = :event_id" -default 0]			
			
			if {!$already_invited_p} {
				# Check if they are already registered
				set party_id [party::get_by_email -email "$email"]
				if {$party_id ne ""} {
					set already_invited_p [db_string participant "select 1 from flyhh_event_participants where project_id = :context_id and person_id = :party_id" -default 0]
				}
			}
			
			if {!$already_invited_p} {

				set party_id [party::get_by_email -email "$email"]
				set salutation $default_salutation
								
				if {$party_id ne ""} {
					
					# User probably is in the system, try if we can personalize the invitation further
					set first_names [db_string first_names "select first_names from persons pe where person_id = :party_id" -default ""]
					if {$first_names ne ""} {
						set salutation "Dear ${first_names}!"
					}
				}
				
				set token [ns_sha1 "${email}${event_id}"]
				set registration_url [export_vars -base "[ad_url]/flyhh/registration" -url {token email event_id}]
				   
					
				eval [template::adp_compile  -string "$content_body"]
				set body $__adp_output
					
				eval [template::adp_compile -string "$subject"]
				set subject $__adp_output
				
				acs_mail_lite::send -send_immediately -to_addr $email -from_addr "$event_email" -subject $subject -body $body -mime_type "text/html" -object_id $context_id
				
				# Try to find the log_id
				if {$party_id ne ""} {
					set mail_log_id [db_string mail_log "select ml.log_id from acs_mail_log ml, acs_mail_log_recipient_map rm
						where rm.log_id = ml.log_id
						and  rm.recipient_id = :party_id
						and ml.context_id = :context_id limit 1" -default ""]
				} else {
					set mail_log_id [db_string mail_log "select log_id from acs_mail_log where to_addr = :email and context_id = :context_id limit 1" -default ""]
				}
				
				# Record the message sending
				db_dml log_invite "insert into flyhh_event_participant_invitation (email,event_id,mail_log_id) values (:email,:event_id,:mail_log_id)"
				util_user_message -html -message "E-Mail send to $email<br />"
				ds_comment  "E-Mail send to $email<br />"
				
		    } else {
				ns_log notice "No invitation sen to User::${email}::"
				util_user_message -html -message "NO E-Mail send to $email .. Already send !!!!<br />"
				ds_comment "NO E-Mail send to $email .. Already send !!!!<br />"
		    }
		}
    } -after_submit {
		rp_internal_redirect "/packages/intranet-cust-flyhh/www/admin/index"
    }
