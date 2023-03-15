# Sonos Orchestrations

Add-Type -AssemblyName System.Web

function HtmlDecode
(
    [String] $data
)
{
    $data = $data -replace '\x26lt\x3b', '<'
    $data = $data -replace '\x26gt\x3b', '>'
    return $data
}

function Execute-SOAPRequest 
( 
        [Xml]    $SOAPRequest, 
        [String] $URL,
        [String] $SOAPAction
) 
{ 
        $soapWebRequest = [System.Net.WebRequest]::Create($URL) 
        $soapWebRequest.Headers.Add("SOAPAction",$SOAPAction)
        $soapWebRequest.ContentType = "text/xml;charset=`"utf-8`"" 
        $soapWebRequest.Method      = "POST" 
        
        $requestStream = $soapWebRequest.GetRequestStream() 
        $SOAPRequest.Save($requestStream) 
        $requestStream.Close() 
        
        $resp = $soapWebRequest.GetResponse() 
        $responseStream = $resp.GetResponseStream() 
        $soapReader = [System.IO.StreamReader]($responseStream) 
        $ReturnXml = [Xml] $soapReader.ReadToEnd() 
        $responseStream.Close() 
        #Write-Host $ReturnXml.OuterXml
        return $ReturnXml.OuterXml
}

function Sonos-Get-Random-Deccrement
(
    [int] $input_value
)
{
    $random_value = Get-Random -Minimum 1 -Maximum 10
    write-host $random_value
    $value = ($input_value - $random_value)
    if ($value -lt 10) {
        $value = 10
    }
    return $value
}

function Sonos-Get-Random-Increment
(
    [int] $input_value
)
{
    $random_value = Get-Random -Minimum 1 -Maximum 10
    write-host $random_value
    $value = ($input_value + $random_value)
    if ($value -gt 99) {
        $value = 99
    }
    return $value
}


function Sonos-Parse-Media-Info
(
    [String] $media_info
)
{
    $Namespace = @{
        s = "http://schemas.xmlsoap.org/soap/envelope/"
        u = "urn:schemas-upnp-org:service:AVTransport:1"
    }

    $doc = [Xml] $media_info
    #<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
    #  <s:Body>
    #    <u:GetMediaInfoResponse xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
    #      <NrTracks>1</NrTracks>
    #      <MediaDuration>NOT_IMPLEMENTED</MediaDuration>
    #      <CurrentURI>x-sonos-vli:RINCON_F0F6C187DE8401400:1,airplay:0daef8fe8fc0443fb561b5cad94bfb76</CurrentURI>
    #      <CurrentURIMetaData>&lt;DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/" xmlns:r="urn:schemas-rinconnetworks-com:metadata-1-0/" xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/"&gt;&lt;item id="airplay" parentID="0" restricted="false"&gt;&lt;dc:title&gt;AirPlay&lt;/dc:title&gt;&lt;upnp:class&gt;object.item.audioItem.linein.airplay&lt;/upnp:class&gt;&lt;res protocolInfo="x-sonos-vli:*:audio:*"&gt;x-sonos-vli:RINCON_F0F6C187DE8401400:1,airplay:0daef8fe8fc0443fb561b5cad94bfb76&lt;/res&gt;&lt;vli cookie="6" group=""&gt;&lt;/vli&gt;&lt;/item&gt;&lt;/DIDL-Lite&gt;</CurrentURIMetaData>
    #      <NextURI></NextURI>
    #      <NextURIMetaData></NextURIMetaData>
    #      <PlayMedium>NETWORK</PlayMedium>
    #      <RecordMedium>NOT_IMPLEMENTED</RecordMedium>
    #      <WriteStatus>NOT_IMPLEMENTED</WriteStatus>
    #    </u:GetMediaInfoResponse>
    #  </s:Body>
    #</s:Envelope>

    $nrtracks = Select-Xml -Xml $doc -XPath "//NrTracks"
    write-host $nrtracks

    $media_duration = Select-Xml -Xml $doc -XPath "//MediaDuration"
    write-host $media_duration

    $current_uri = Select-Xml -Xml $doc -XPath "//CurrentURI"
    Write-Host $current_uri

    $current_uri_metadata = Select-Xml -Xml $doc -XPath "//CurrentURIMetaData"
    #Write-Host $current_uri_metadata

    $uri_metadata = HtmlDecode -data $current_uri_metadata
    Write-Host Decoded: $uri_metadata

    Sonos-Parse-DIDL-Lite $uri_metadata
}


function Sonos-Parse-DIDL-Lite
(
    [String] $didl
)
{
    $didl_xpath = @{
        item_id         = "//item/@id"
        item_parentId   = "//item/@parentID"
        item_restricted = "//item/@restricted"

        title           = "//title/text()"
        class           = "//class/text()"

        vli_cookie      = "//vli/@cookie"
        vli_group       = "//vli/@group"
        vli_contents    = "//vli/text()"

    }

    #write-host DIDL: $didl

    # Remove regular namespace for DIDL    
    $didl = $didl -replace '\sxmlns\x3d\x22urn\x3aschemas\x2dupnp\x2dorg\x3ametadata\x2d1\x2d0\x2fDIDL\x2dLite\x2f\x22', ""

    # Remove namespace "r"
    $didl = $didl -replace '\sxmlns\x3ar\x3d\x22urn\x3aschemas\x2drinconnetworks\x2dcom\x3ametadata\x2d1\x2d0\x2f\x22', ""
    $didl = $didl -replace '\x3cr\x3a', "<"
    $didl = $didl -replace '\x3c\x2fr\x3a', "</"

    # Remove namespace "upnp"
    $didl = $didl -replace '\sxmlns\x3aupnp\x3d\x22urn\x3aschemas\x2dupnp\x2dorg\x3ametadata\x2d1\x2d0\x2fupnp\x2f\x22', ""
    $didl = $didl -replace '\x3cupnp\x3a', "<"
    $didl = $didl -replace '\x3c\x2fupnp\x3a', "</"

    # Remove namespace "dc"
    $didl = $didl -replace '\sxmlns\x3adc\x3d\x22http\x3a\x2f\x2fpurl\x2eorg\x2fdc\x2felements\x2f1\x2e1\x2f\x22', ""
    $didl = $didl -replace '\x3cdc\x3a', "<"
    $didl = $didl -replace '\x3c\x2fdc\x3a', "</"
    
    #write-host DIDL: $didl

    $doc = [Xml] $didl

    foreach($key in $($didl_xpath.Keys)) {
        #write-host $key
        $xpath = $didl_xpath[$key]
        Write-Host $key $xpath

        #try {
        #    $value = Select-Xml -Xml $doc -XPath $xpath
        #}
        #except {
        #}

        Write-Host $value
    }

    $didl_obj["item_id"]   = Select-Xml -Xml $doc -XPath "//item/@id"
    $item_parentID         = Select-Xml -Xml $doc -XPath "//item/@parentID"
    $item_restricted       = Select-Xml -Xml $doc -XPath "//item/@restricted"
    $res_duration          = Select-Xml -Xml $doc -XPath "//res/@duration"

    $title                 = Select-Xml -Xml $doc -XPath "//title/text()"

    $class                 = Select-Xml -Xml $doc -XPath "//class/text()"

    $res_protocolinfo      = Select-Xml -Xml $doc -XPath "//res/@protocolInfo"
    $res_text              = Select-Xml -Xml $doc -XPath "//res/text()"

    $vli_cookie            = Select-Xml -Xml $doc -XPath "//vli/@cookie"
    $vli_group             = Select-Xml -Xml $doc -XPath "//vli/@group"
    $vli_text              = Select-Xml -Xml $doc -XPath "//vli/text()"

    $albumArtURI           = Select-Xml -Xml $doc -XPath "//albumArtURI/text()"
    $album                 = Select-Xml -Xml $doc -XPath "//album/text()"

    $originalTrackNumber   = Select-Xml -Xml $doc -XPath "//originalTrackNumber/text()"

    $creator               = Select-Xml -Xml $doc -XPath "//creator/text()"

    $tiid                  = Select-Xml -Xml $doc -XPath "//tiid/text()"

    Write-Host $didl_obj | Format-Table


    write-host itemId: $item_id
    Write-Host item_parentId: $item_parentID
    write-host item_restricted: $item_restricted

    write-host $res_duration

    Write-Host $title

    Write-Host $class

    Write-Host $res_protocolinfo
    Write-Host $res_text

    write-host $vli_cookie
    Write-Host $vli_group
    Write-Host $vli_text

    Write-Host $albumArtURI

    Write-Host $album

    Write-Host $originalTrackNumber


    Write-Host $creator

    Write-Host $tiid

    Write-Host $didl


}


function Sonos-Parse-GetPositionInfoResponse
(
    [String] $SOAPResponse
)
{
    $Namespace = @{
        s = "http://schemas.xmlsoap.org/soap/envelope/"
        u = "urn:schemas-upnp-org:service:AVTransport:1"
    }
    
    $doc = [Xml] $SOAPResponse
    
    $body_track_number     = Select-Xml -Xml $doc -Namespace $Namespace -XPath "//s:Body/u:GetPositionInfoResponse/Track"
    $body_track_duration   = Select-Xml -Xml $doc -Namespace $Namespace -XPath "//s:Body/u:GetPositionInfoResponse/TrackDuration"
    $body_track_reltime    = Select-Xml -Xml $doc -Namespace $Namespace -XPath "//s:Body/u:GetPositionInfoResponse/RelTime"
    $body_track_abstime    = Select-Xml -Xml $doc -Namespace $Namespace -XPath "//s:Body/u:GetPositionInfoResponse/AbsTime"
    $body_track_relcount   = Select-Xml -Xml $doc -Namespace $Namespace -XPath "//s:Body/u:GetPositionInfoResponse/RelCount"
    $body_track_abscount   = Select-Xml -Xml $doc -Namespace $Namespace -XPath "//s:Body/u:GetPositionInfoResponse/AbsCount"
    $body_trackmetadata    = Select-Xml -Xml $doc -Namespace $Namespace -XPath "//s:Body/u:GetPositionInfoResponse/TrackMetaData" 

    $trackmetadata = HtmlDecode -data $body_trackmetadata
    
    Write-Host $body_track_number
    Write-Host $body_track_duration
    Write-Host $body_track_reltime
    Write-Host $body_track_abstime
    Write-Host $body_track_relcount
    Write-Host $body_track_abscount

    Sonos-Parse-DIDL-Lite -didl $trackmetadata
    


}

function Sonos-Get-Volume
(
    [String] $destinationHost,
    [String] $destinationPort
)
{

    $URL = "http://" + $destinationHost + ':' + $destinationPort + '/MediaRenderer/RenderingControl/Control'
    $soapRequest = '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body><u:GetVolume xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1"><InstanceID>0</InstanceID><Channel>Master</Channel></u:GetVolume></s:Body></s:Envelope>'
    $soapAction = 'urn:schemas-upnp-org:service:RenderingControl:1#GetVolume'
    $response = Execute-SOAPRequest -URL $URL -SOAPAction $soapAction -SOAPRequest $soapRequest
    return $response
}

function Sonos-Set-Volume
(
    [String] $destinationHost,
    [String] $destinationPort,
    [Int] $volumeLevel
)
{
    $URL = "http://" + $destinationHost + ':' + $destinationPort + '/MediaRenderer/RenderingControl/Control'
    $soapRequest = '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body><u:SetVolume xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1"><InstanceID>0</InstanceID><Channel>Master</Channel><DesiredVolume>' + $volumeLevel + '</DesiredVolume></u:SetVolume></s:Body></s:Envelope>'
    $soapAction = 'urn:schemas-upnp-org:service:RenderingControl:1#SetVolume'
    $response = Execute-SOAPRequest -URL $URL -SOAPAction $soapAction -SOAPRequest $soapRequest
}

function Sonos-Get-Loudness
(
    [String] $destinationHost,
    [String] $destinationPort
)
{
    $URL = "http://" + $destinationHost + ':' + $destinationPort + '/MediaRenderer/RenderingControl/Control'
    $soapRequest = '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body><u:GetLoudness xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1"><InstanceID>ui4</InstanceID><Channel>Master</Channel></u:GetLoudness></s:Body></s:Envelope>'
    $soapAction = 'urn:schemas-upnp-org:service:RenderingControl:1#GetLoudness'
    $response = Execute-SOAPRequest -URL $URL -SOAPAction $soapAction -SOAPRequest $soapRequest
    return $response
}

function Sonos-Set-Loudness
(
    [String] $destinationHost,
    [String] $destinationPort,
    [Bool] $Loudness
)
{
    if ($Loudness -eq $true) {
        $LoudnessValue = "true"
    } else {
        $LoudnessValue = "false"
    }

    $URL = "http://" + $destinationHost + ':' + $destinationPort + '/MediaRenderer/RenderingControl/Control'
    $soapRequest = '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body><u:SetLoudness xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1"><InstanceID>0</InstanceID><Channel>Master</Channel><DesiredLoudness>'+ $loudnessValue +'</DesiredLoudness></u:SetLoudness></s:Body></s:Envelope>'
    $soapAction = 'urn:schemas-upnp-org:service:RenderingControl:1#SetLoudness'
    $response = Execute-SOAPRequest -URL $URL -SOAPAction $soapAction -SOAPRequest $soapRequest
}

function Sonos-Get-Bass
(
    [String] $destinationHost,
    [String] $destinationPort
)
{
    $URL = "http://" + $destinationHost + ':' + $destinationPort + '/MediaRenderer/RenderingControl/Control'
    $soapRequest = '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body><u:GetBass xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1"><InstanceID>0</InstanceID></u:GetBass></s:Body></s:Envelope>'
    $soapAction = 'urn:schemas-upnp-org:service:RenderingControl:1#GetBass'
    $response = Execute-SOAPRequest -URL $URL -SOAPAction $soapAction -SOAPRequest $soapRequest
    return $response
}

function Sonos-Set-Bass
(
    [String] $destinationHost,
    [String] $destinationPort,
    [int] $bassLevel
)
{
    $URL = "http://" + $destinationHost + ':' + $destinationPort + '/MediaRenderer/RenderingControl/Control'
    $soapRequest = '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body><u:SetBass xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1"><InstanceID>0</InstanceID><DesiredBass>' + $bassLevel + '</DesiredBass></u:SetBass></s:Body></s:Envelope>'
    $soapAction = 'urn:schemas-upnp-org:service:RenderingControl:1#SetBass'
    $response = Execute-SOAPRequest -URL $URL -SOAPAction $soapAction -SOAPRequest $soapRequest
}

function Sonos-Play
(
    [String] $destinationHost,
    [String] $destinationPort
)
{
    $URL = "http://" + $destinationHost + ':' + $destinationPort + '/MediaRenderer/AVTransport/Control'
    $soapRequest = '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body><u:Play xmlns:u="urn:schemas-upnp-org:service:AVTransport:1"><InstanceID>0</InstanceID><Speed>1</Speed></u:Play></s:Body></s:Envelope>'
    $soapAction = 'urn:schemas-upnp-org:service:AVTransport:1#Play'
    $response = Execute-SOAPRequest -URL $URL -SOAPAction $soapAction -SOAPRequest $soapRequest
}

function Sonos-Pause
(
    [String] $destinationHost,
    [String] $destinationPort
)
{
    $URL = "http://" + $destinationHost + ':' + $destinationPort + '/MediaRenderer/AVTransport/Control'
    $soapRequest = '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body><u:Pause xmlns:u="urn:schemas-upnp-org:service:AVTransport:1"><InstanceID>0</InstanceID></u:Pause></s:Body></s:Envelope>'
    $soapAction = 'urn:schemas-upnp-org:service:AVTransport:1#Pause'
    $response = Execute-SOAPRequest -URL $URL -SOAPAction $soapAction -SOAPRequest $soapRequest
}

function Sonos-Next
(
    [String] $destinationHost,
    [String] $destinationPort
)
{
    $URL = "http://" + $destinationHost + ':' + $destinationPort + '/MediaRenderer/AVTransport/Control'
    $soapRequest = '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body><u:Next xmlns:u="urn:schemas-upnp-org:service:AVTransport:1"><InstanceID>0</InstanceID></u:Next></s:Body></s:Envelope>'
    $soapAction = 'urn:schemas-upnp-org:service:AVTransport:1#Next'
    $response = Execute-SOAPRequest -URL $URL -SOAPAction $soapAction -SOAPRequest $soapRequest
}

function Sonos-Previous
(
    [String] $destinationHost,
    [String] $destinationPort
)
{
    $URL = "http://" + $destinationHost + ':' + $destinationPort + '/MediaRenderer/AVTransport/Control'
    $soapRequest = '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body><u:Previous xmlns:u="urn:schemas-upnp-org:service:AVTransport:1"><InstanceID>ui4</InstanceID></u:Previous></s:Body></s:Envelope>'
    $soapAction = 'urn:schemas-upnp-org:service:AVTransport:1#Previous'
    $response = Execute-SOAPRequest -URL $URL -SOAPAction $soapAction -SOAPRequest $soapRequest
}

function Sonos-Get-Position-Info
(
    [String] $destinationHost,
    [String] $destinationPort
)
{
    $URL = "http://" + $destinationHost + ':' + $destinationPort + '/MediaRenderer/AVTransport/Control'
    $soapRequest = '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body><u:GetPositionInfo xmlns:u="urn:schemas-upnp-org:service:AVTransport:1"><InstanceID>0</InstanceID></u:GetPositionInfo></s:Body></s:Envelope>'
    $soapAction = 'urn:schemas-upnp-org:service:AVTransport:1#GetPositionInfo'
    $response = Execute-SOAPRequest -URL $URL -SOAPAction $soapAction -SOAPRequest $soapRequest
    #Write-Host $response

    Sonos-Parse-GetPositionInfoResponse -SOAPResponse $response
}

function Sonos-Get-Media-Info
(
    [String] $destinationHost,
    [String] $destinationPort
)
{

    $URL = "http://" + $destinationHost + ':' + $destinationPort + '/MediaRenderer/AVTransport/Control'
    $soapRequest = '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body><u:GetMediaInfo xmlns:u="urn:schemas-upnp-org:service:AVTransport:1"><InstanceID>0</InstanceID></u:GetMediaInfo></s:Body></s:Envelope>'
    $soapAction = 'urn:schemas-upnp-org:service:AVTransport:1#GetMediaInfo'
    $response = Execute-SOAPRequest -URL $URL -SOAPAction $soapAction -SOAPRequest $soapRequest

    #Write-Host $response
    Sonos-Parse-Media-Info $response
}

function Sonos-Get-TransportSettings
(
    [String] $destinationHost,
    [String] $destinationPort
)
{
    $URL = "http://" + $destinationHost + ':' + $destinationPort + '/MediaRenderer/AVTransport/Control'
    $soapRequest = '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body><u:GetTransportSettings xmlns:u="urn:schemas-upnp-org:service:AVTransport:1"><InstanceID>0</InstanceID></u:GetTransportSettings></s:Body></s:Envelope>'
    $soapAction = 'urn:schemas-upnp-org:service:AVTransport:1#GetTransportSettings'
    $response = Execute-SOAPRequest -URL $URL -SOAPAction $soapAction -SOAPRequest $soapRequest
    return $response
}

function Sonos-Get-MusicIndex
(
    [String] $destinationHost,
    [String] $destinationPort
)
{
    $URL = "http://" + $destinationHost + ':' + $destinationPort + '/MediaServer/ContentDirectory/Control'
    $soapRequest = '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body><u:Browse xmlns:u="urn:schemas-upnp-org:service:ContentDirectory:1"><ObjectID>A:ARTIST</ObjectID><BrowseFlag>BrowseDirectChildren</BrowseFlag><Filter>*</Filter><StartingIndex>0</StartingIndex><RequestedCount>10</RequestedCount><SortCriteria>*</SortCriteria></u:Browse></s:Body></s:Envelope>'
    $soapAction = 'urn:schemas-upnp-org:service:ContentDirectory:1#Browse'
    $response = Execute-SOAPRequest -URL $URL -SOAPAction $soapAction -SOAPRequest $soapRequest
    return $response
}



Clear-Host

$destination_ip = "172.17.138.191" # Sonos One

$destination_port = "1400"


#Sonos-Get-Position-Info -destinationHost $destination_ip -destinationPort $destination_port

#Sonos-Get-Media-Info -destinationHost $destination_ip -destinationPort $destination_port

#Sonos-Get-MusicIndex -destinationHost $destination_ip -destinationPort $destination_port 


#Sonos-Set-Loudness -destinationHost $destination_ip -destinationPort $destination_port -Loudness $true
#Sonos-Set-Bass -destinationHost $destination_ip -destinationPort $destination_port -bassLevel 10
#Sonos-Set-Volume -destinationHost $destination_ip -destinationPort $destination_port -volumeLevel 46


if (1 -eq 1) {
    $Namespace = @{
        s = "http://schemas.xmlsoap.org/soap/envelope/"
        u = "urn:schemas-upnp-org:service:AVTransport:1"
    }

    [Xml] $volumeLevel = Sonos-Get-Volume -destinationHost $destination_ip -destinationPort $destination_port 

    $volumeLevelValue = Select-Xml -Xml $volumeLevel -Namespace $Namespace -XPath "//CurrentVolume/text()"
    $volumeLevelValue = [convert]::ToInt32($volumeLevelValue, 10)
    Write-Host $volumeLevelValue

    $changed_volume = 0
    if (($volumeLevelValue -gt 1) -and ($changed_volume -eq 0)) {
        $volumeLevelValue = Sonos-Get-Random-Increment -input_value $volumeLevelValue
        $changed_volume += 1

    }
    
    if (($volumeLevelValue -lt 90) -and ($changed_volume -eq 0)) {
        $voluleLevelValue = Sonos-Get-Random-Deccrement -input_value $volumeLevelValue
        $changed_volume -= 1
    }

    Write-Host $volumeLevelValue

    #Sonos-Pause -destinationHost $destination_ip -destinationPort $destination_port

    #Sonos-Next -destinationHost $destination_ip -destinationPort $destination_port
    #Sonos-Next -destinationHost $destination_ip -destinationPort $destination_port

    #Sonos-Previous -destinationHost $destination_ip -destinationPort $destination_port 
    
    Sonos-Set-Volume -destinationHost $destination_ip -destinationPort $destination_port -volumeLevel 99
    Sonos-Set-Loudness -destinationHost $destination_ip -destinationPort $destination_port -Loudness $true
    Sonos-Set-Bass -destinationHost $destination_ip -destinationPort $destination_port -bassLevel 10
    #Sonos-Set-Volume -destinationHost $destination_ip -destinationPort $destination_port -volumeLevel 96
    
    #Sonos-Set-Volume -destinationHost $destination_ip -destinationPort $destination_port -volumeLevel $volumeLevelValue

    #Sonos-Set-Volume -destinationHost $destination_ip -destinationPort $destination_port -volumeLevel 3


    #Sonos-Set-Volume -destinationHost $destination_ip -destinationPort $destination_port -volumeLevel 84


}


if (1 -eq 0) {
    $Namespace = @{
        s = "http://schemas.xmlsoap.org/soap/envelope/"
        u = "urn:schemas-upnp-org:service:AVTransport:1"
    }
    [Xml] $bassLevel = Sonos-Get-Bass -destinationHost $destination_ip -destinationPort $destination_port
    Write-Host $bassLevel
    [int16] $bassLevelValue = Select-Xml -Xml $bassLevel -Namespace $Namespace -XPath "//CurrentBass/text()"
    Write-Host $bassLevelValue
    
    #$bassLevel = ($bassLevel - 1)
    $bassLevelValue = $bassLevelValue - 1

    if ($bassLevelValue -lt -10) {
        $bassLevelValue = -10
    }
    if ($bassLevelValue -gt 10) {
        $bassLevelValue = 10
    }
    #Sonos-Set-Bass -destinationHost $destination_ip -destinationPort $destination_port -bassLevel $bassLevelValue
}

#$loudness = Sonos-Get-Loudness -destinationHost $destination_ip -destinationPort $destination_port
#Write-Host $loudness


#Sonos-Pause -destinationHost $destination_ip -destinationPort $destination_port
#Sonos-Set-Volume -destinationHost 10.100.43.131 -destinationPort 1400 -volumeLevel 61

#Sonos-Set-Loudness -destinationHost $destination_ip -destinationPort $destination_port -Loudness $true
#Sonos-Set-Loudness -destinationHost $destination_ip -destinationPort $destination_port -Loudness $false

#Sonos-Set-Bass -destinationHost $destination_ip -destinationPort $destination_port -bassLevel 7


#Sonos-Next -destinationHost $destination_ip -destinationPort $destination_port
#Sonos-Previous -destinationHost $destination_ip -destinationPort $destination_port

#$transportsettings = Sonos-Get-TransportSettings -destinationHost $destination_ip -destinationPort $destination_port
#Write-Host $transportsettings

