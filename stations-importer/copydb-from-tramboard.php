<?php

$handle = new SQLite3("../../tramboard-clj/stations.sqlite");
$handle2 = new SQLite3("../timeforcoffeeKit/SingleViewCoreData.sqlite");
$results = $handle->query("select Z_PK, Z_ENT, Z_OPT, ZLASTUPDATED, ZLATITUDE, ZLONGITUDE, ZCOUNTRYISO, ZID, ZNAME from ZTFCSTATIONMODEL ");
$handle2->exec("drop TABLE zvv_to_sbb");
$handle2->exec("drop index ZAPIID");
$handle2->exec("drop index ZAPIKEY");

$handle2->exec("delete from ZTFCSTATIONMODEL");
$handle2->exec("delete from ZTFCDEPARTURE");
while ($row = $results->fetchArray(SQLITE3_ASSOC)) {

    
    $values = array_map( function($value) { return "'".SQLite3::escapeString($value)."'";}, $row);
    $sql = "INSERT INTO ZTFCSTATIONMODEL (" . implode(array_keys($row),", ").") VALUES (" . implode($values, ", ") . ")";
    print ".";
    $handle2->exec($sql);
}
    
    
$handle2->exec("VACUUM FULL");

