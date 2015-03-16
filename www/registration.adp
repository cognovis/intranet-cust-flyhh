 <master src=@adp_master@>
<if @mode@ eq "display">
    <center>#intranet-cust-flyhh.lt_THANK_YOU_FOR_YOUR_RE#<center><p />
    #intranet-cust-flyhh.lt_You_will_receive_an_E#<p />
    </if>
<div style="width:620px;">
    <formtemplate id="@form_id@" style="tiny-plain-po"></formtemplate>
</div>
<if @mode@ eq "display">

<div class="fb-like" data-href="@facebook_event_url;noquote@" data-layout="standard" data-action="like" data-show-faces="true" data-share="true"></div>
<div class="fb-follow" data-href="@facebook_orga_url;noquote@" data-colorscheme="light" data-layout="standard" data-show-faces="true"></div>

</if>