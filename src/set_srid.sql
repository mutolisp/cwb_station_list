BEGIN;
UPDATE 
    cwb_station_list 
    SET geom_wgs84 = s.wgs84 
FROM 
    (SELECT station_id, st_setsrid(st_makepoint(longitude,latitude), 4326) wgs84 
     FROM cwb_station_list) as s 
WHERE 
    cwb_station_list.station_id = s.station_id;
COMMIT;
-- 轉換座標系統
BEGIN;
UPDATE 
    cwb_station_list
SET 
    geom_twd97 = st_transform(geom_wgs84, 3826);
COMMIT;
