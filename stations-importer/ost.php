<?php

$handle = new SQLite3("../../tramboard-clj/stations.sqlite");
$results = $handle->query("select * from ZTFCSTATIONMODEL where (ZCOUNTY = 'Schwyz' OR ZCOUNTY = 'St. Gallen' OR ZCOUNTY = 'Thurgau' OR ZCOUNTY = 'Glarus' OR ZCOUNTY LIKE 'Appen%')  AND (ZAPIKEY ISNULL) "); 
while ($row = $results->fetchArray()) {
        print $row['ZNAME'] . " ";
       $url = "http://localhost:3000/api/ost/stationboard/" .  urlencode($row['ZID']);
    //print "$url\n";
    $json = @file_get_contents($url);
    if (!$json) {
        print $url . " could not be retrieved! \n";
        continue;
    }

    $hasrealtime = false;
    $json = json_decode($json, true);
    if (isset($json['departures'])) {
        foreach($json['departures'] as $dept) {
            if (isset($dept['departure']['realtime'])) {
                $hasrealtime = true;
                break;
            }
        }
    }
    if ($hasrealtime) {
        print " ! has realtime data";
        $handle->exec("update ZTFCSTATIONMODEL set  ZAPIKEY = 'ost' where ZID = '". $row['ZID'] . "'");
    } else {
        print " - no realtime data ";
    } 
    
    print "\n";
}

$results = $handle->query("select * from ZTFCSTATIONMODEL where NOT (ZNAME LIKE '%,%') AND ZAPIKEY = 'ost'");
while ($row = $results->fetchArray()) {
    $results2 = $handle->query("select * from ZTFCSTATIONMODEL where (ZNAME LIKE '" . $row['ZNAME'] . ", Bahnhof') AND ZAPIKEY = 'ost'");
    while ($row2 = $results2->fetchArray()) {
        print $row['ZNAME'] . "\n";
        $handle->exec("update ZTFCSTATIONMODEL set  ZAPIID = '". $row2['ZID']. "' where ZID = '". $row['ZID'] . "'");

    }
}

//$handle->exec("update ZTFCSTATIONMODEL set  ZAPIID = null, zapikey = nil where ZID = '". $row['ZID'] . "'");

/*



$r = new DomDocument();
$r->loadXML($json);
$xp = new DOmXPath($r);
$maxqual = 1;
foreach ($xp->query("/efa/sf/p") as $foo) {
    $q = $xp->query("qal", $foo);
    if (isset ($q[0])) {
        $qual = $q[0]->nodeValue;
        if ($qual > 700 && $qual >= $maxqual) {
            $city = $xp->query("r/pc",$foo);
            $id = $xp->query("r/id",$foo);
            $name = $xp->query("n",$foo);
            $maxqual = $qual;
        } 
    } else {
        $city = $xp->query("r/pc",$foo);
        $name = $xp->query("n",$foo);
        $id = $xp->query("r/id",$foo);                
    }
    
}
if (isset ($id[0])) {
    $oriname = $city[0]->nodeValue . ", ". $name[0]->nodeValue;
    print $oriname;
    
    $id = $id[0]->nodeValue;
    $url2 = 'http://mobil.vbl.ch/vblUltra/XML_DM_REQUEST?type_dm=any&trITMOTvalue100=10&changeSpeed=normal&mergeDep=1&coordOutputFormat=MRCV&coordListOutputFormat=STRING&useAllStops=1&excludedMeans=checkbox&useRealtime=1&itOptionsActive=1&canChangeMOT=0&mode=direct&ptOptionsActive=1&imparedOptionsActive=1&depType=stopEvents&locationServerActive=1&maxTimeLoop=2&includeCompleteStopSeq=0&useProxFootSearch=0&name_dm=' . $id; 
    $station = file_get_contents($url2);
    $r = new DomDocument();
    $r->loadXML($station);
    $xp = new DOmXPath($r);
    $res = $xp->query("/efa/dps/dp/realtime[text() = 1]");
    
    if ($res->length > 0) {
        print " ! has realtime data";
        $handle->exec("update ZTFCSTATIONMODEL set ZORINAME = '" .  SQLite3::escapeString($oriname) . "', ZAPIKEY = 'vbl', ZAPIID =  '". $id  . "' where ZID = '". $row['ZID'] . "'");
    } else {
        print " - no realtime data ($id)";
    }
    print "\n";
}
$id = null;   

}*/

