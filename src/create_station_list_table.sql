
-- 如果 cwb_station_list 資料表存在的話，則刪除之
DROP TABLE IF EXISTS cwb_station_list;
CREATE TABLE public.cwb_station_list
(
  station_id character varying NOT NULL, -- 站號
  station character varying, -- 站名
  county character varying, -- 縣市
  township character varying, -- 鄉鎮
  longitude double precision, -- 經度
  latitude double precision, -- 緯度
  elevation double precision, -- 海拔高度
  address character varying, -- 地址
  establish_date date, -- 資料起始日期
  revoke_date date, -- 撤站日期
  note character varying, -- 備註
  twd97x double precision, -- TWD97X 座標
  twd97y double precision, -- TWD97Y 座標
  geom_twd97 geometry(Point,3826), -- twd97 geometry column
  geom_wgs84 geometry(Point,4326), -- wgs84 geometry column
  station_type character varying, -- 測站類型
  CONSTRAINT cwb_stations_pk PRIMARY KEY (station_id)
)
WITH (
  OIDS=FALSE
);
