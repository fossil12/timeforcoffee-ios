<?php

$handle = new SQLite3("../../tramboard-clj/stations.sqlite");
$results = $handle->query("select * from ZTFCSTATIONMODEL where (ZCOUNTY LIKE 'Bas%')  AND (ZAPIID ISNULL OR ZAPIID = '') "); 
while ($row = $results->fetchArray()) {
    $url = "http://efa-bw.de/ios_bvb/XML_STOPFINDER_REQUEST?coordOutputFormat=NBWT&type_sf=any&locationServerActive=1&stateless=1&useHouseNumberList=true&doNotSearchForStops=1&reducedAnyWithoutAddressObjFilter_sf=103&reducedAnyPostcodeObjFilter_sf=64&reducedAnyTooManyObjFilter_sf=2&anyObjFilter_sf=126&anyMaxSizeHitList=600&w_regPrefAl=2&prMinQu=1&name_sf=" .  urlencode($row['ZNAME']);
    //print "$url\n";
    $json = file_get_contents($url);
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
        print $row['ZNAME'] . " \t-> " .$oriname;
        
        $id = $id[0]->nodeValue;
        $url2 = 'http://efa-bw.de/ios_bvb/XML_DM_REQUEST?type_dm=any&trITMOTvalue100=10&changeSpeed=normal&mergeDep=1&coordOutputFormat=NBWT&coordListOutputFormat=STRING&useAllStops=1&excludedMeans=checkbox&useRealtime=1&itOptionsActive=1&canChangeMOT=0&mode=direct&ptOptionsActive=1&imparedOptionsActive=1&depType=stopEvents&locationServerActive=1&useProxFootSearch=0&maxTimeLoop=2&includeCompleteStopSeq=0&name_dm=' . $id; 
        $station = file_get_contents($url2);
        $r = new DomDocument();
        $r->loadXML($station);
        $xp = new DOmXPath($r);
        $res = $xp->query("/efa/dps/dp/realtime[text() = 1]");
         
        if ($res->length > 0) {
            print " ! has realtime data";
            $handle->exec("update ZTFCSTATIONMODEL set ZAPIKEY = 'bvb', ZAPIID =  '". $id  . "' where ZID = '". $row['ZID'] . "'");
        } else {
            print " - no realtime data ($id)";
        }
        print "\n";
    }
    $id = null;   
    
}

