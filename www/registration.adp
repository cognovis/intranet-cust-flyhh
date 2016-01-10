 <master src=@adp_master@>
<style type="text/css" id="form-css">

.form-widget-error, .form-required-mark, .form-error {
		    color: #c30000;
}

strong.form-required-mark {
    font-weight: inherit;
}

.form-label-error {
		  font-weight: bold;
}

.form-fieldset {
	       border: 0px solid #000;
}

.form-legend {
    font-weight: bold;
}

legend span { 
    display: block;
}

/* form layout for forms with divs */

.margin-form .form-required-mark {
    display: inline;
}

.margin-form .form-item-wrapper {
	     clear: both;
	     padding: 5px;
}	     

.margin-form .form-item-wrapper .form-label {
	     float: left;
	     text-align: right;
	     display: block;
	     width: 16em;
}

.margin-form .form-item-wrapper .form-widget, .margin-form .form-button, .margin-form .form-help-text {
	     display: block;
	     margin-left: 17em;
}

.margin-form .form-button {
	     margin-top: 1em;
}

.margin-form .form-item-wrapper .form-error, .margin-form .form-item-wrapper .form-widget-error {
	     display: block;
	     margin-left: 17em;
}

.vertical-form .form-required-mark {
    display: inline;
}

.vertical-form .form-item-wrapper {
	       clear: both;
	       padding: 8px;
}	       

.vertical-form .form-item-wrapper .form-label {
	       text-align: left;
	       display: block;

}

.vertical-form .form-item-wrapper .form-widget{
	       display: inline;

}


.inline-form div {
	     display: inline;	
}


/* pages that are laid out like forms but do not use the form builder and do not have input fields*/
.margin-form-div .form-item-wrapper {
		 padding-bottom: 10px;
}

.margin-form-div h1 {
		 margin-left: 13.5em;
}

div.form-item-wrapper label {
  display:inline;
}
</style>
<if @mode@ eq "display">
    <center>#intranet-cust-flyhh.lt_THANK_YOU_FOR_YOUR_RE#<p />
    #intranet-cust-flyhh.lt_You_will_receive_an_E#</center><p />
<hr />
    </if>
<div style="width:620px;">
    <formtemplate id="@form_id@" style="standard"></formtemplate>
</div>
<if @mode@ eq "display">

<div class="fb-like" data-href="@facebook_event_url;noquote@" data-layout="standard" data-action="like" data-show-faces="true" data-share="true"></div>
<div class="fb-follow" data-href="@facebook_orga_url;noquote@" data-colorscheme="light" data-layout="standard" data-show-faces="true"></div>

</if>