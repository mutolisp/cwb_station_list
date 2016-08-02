
# 建立中央氣象局測站列表資料表

## 目標

將中央氣象局網頁上的氣象測站點位資料轉換成結構化的資料表，並轉成具有空間資訊的資料表及檔案格式。這樣有什麼好處呢？之後處理資料比較快，而且應用層面也比較廣

## 必須具備的背景知識/技巧

雖然說應該要有一些背景知識，但可以照著步驟仿效，再自己慢慢找資料學。底下兩項是基礎的技能

* 資料庫(知道什麼是 table, constraints, etc.)
    * 為了防止意外，我們使用 [transaction](https://www.postgresql.org/docs/9.5/static/sql-begin.html) 來處理 SQL command，也就是
    
      ```
      1 BEGIN;
      2 SQL
      3 ...
      4 COMMIT;
      ```
      
* shell programming (case switch, EOF(end-of-file, stream text), i/o, sed/awk 這類的 stream editor)，但都不會太難，照範例做改一下就行了。
    * ```#``` 開頭的為 shell script 的註解
    * ```--``` 開頭的為 SQL 的註解
    * EOF 的使用，用 ```cat > filename << _EOF ... _EOF```，中間包起來的文字會存進 ```filename``` 這個檔案中
    ```
    1 cat > filename << _EOF
    2 
    3 abc
    4
    5 _EOF
    ```
    例如上面的源碼中，我們把三行（空白行、abc、空白行)插入到 ```filename``` 中

## 工具

* [PostgreSQL](http://postgresql.org) / [PostGIS extension](http://postgis.net)
  要先把 PostgreSQL 架好至少可以用
* GNU utilities, such as sed, awk
  在 windows 下面使用會有些痛苦，建議你可以用 [cygwin](https://www.cygwin.com) 


## 0. 看一下資料長什麼樣子

網頁資料：
http://e-service.cwb.gov.tw/wdps/obs/state.htm#%B2%7B%A6s%B4%FA%AF%B8

Big5 編碼，用表格處理起來有點麻煩，所以乾脆貼到 LibreOffice 轉成 csv 檔(| 分隔)



```bash
# 現存測站資料
head ../data/cwb_current_station_list.csv
```

    站號|站名|海拔高度(M)|經度|緯度|城市|地址|資料起始日期|撤站日期|備註|原站號|新站號
    466850|五分山雷達站|756|121.7812|25.0712|新北市|瑞芳區靜安路四段1巷1號|1988-07-01||本站只有雷達觀測資料。||
    466880|板橋|9.7|121.442|24.9976|新北市|板橋區大觀路二段265巷62號|1972-03-01||原為探空站，自2002年開始進行氣象觀測。||
    466900|淡水|19|121.4489|25.1649|新北市|淡水區中正東路42巷6號|1942-01-01||||
    466910|鞍部|825.8|121.5297|25.1826|臺北市|北投區陽明山竹子湖路111號|1937-01-01||||
    466920|臺北|6.3|121.5149|25.0377|臺北市|中正區公園路64號|1896-01-01||||
    466930|竹子湖|607.1|121.5445|25.1621|臺北市|北投區陽明山竹子湖路2號|1937-01-01||||
    466940|基隆|26.7|121.7405|25.1333|基隆市|仁愛區港西街6號6樓(海港大樓6樓)|1946-01-01||||
    466950|彭佳嶼|101.7|122.0797|25.628|基隆市|中正區彭佳嶼|1910-01-01||||
    466990|花蓮|16|121.6133|23.9751|花蓮縣|花蓮市花崗街24號|1910-01-01||||



```bash
# 撤站的資料
head ../data/cwb_revoked_station_list.csv
```

    站號|站名|海拔高度(M)|經度|緯度|城市|地址|資料起始日期|撤站日期|備註|原站號|新站號
    466921|臺北(師院)|6.1|121.5132|25.0363|臺北市|中正區公園路|1992-02-01|1997-09-01|1997年9月遷回原址。||
    467411|臺南(永康)|8.1|120.2367|23.0384|臺南市|永康區中正南路654巷40弄1號|1988-05-01|2002-01-01|2002-01-01遷回臺南市。||
    467570|新竹|32.8|120.9776|24.8004|新竹市|公園路|1938-01-01|1991-07-01|1991-07站址遷往竹北。||
    467780|七股|2.9|120.0862|23.147|臺南市|七股區鹽埕237-11號|2001-11-01|2016-06-01|||
    C0A510|大豹|590|121.4215|24.8871|新北市|三峽區(三峽李山神宮附近)|1987-06-01|2009-05-16|||
    C0A590|大尖山|326|121.666|25.0515|新北市|汐止區勤進路|1987-06-01|2011-08-12|||
    C0A680|五股|95|121.435|25.0834|新北市|五股區248成泰路二段49巷15號(五股國中校園內)|2009-12-01|2016-07-02|原(C1A680)站因擴充為氣象站，於2009-12-1升級為(C0A680)站。|C1A680|
    C0A760|林口國中|250|121.3749|25.0815|新北市|林口區林口國中|1973-02-01|1987-12-01|||
    C0A930|三和|200|121.5941|25.2349|新北市|金山區兩湖里(距兩湖分校約300公尺)|1995-01-01|2014-03-20|因移位，於2014-4-1更變為(C0A931)站。||C0A931


## 1. 清理資料

把不要的半型空白和全型空白都去除，另外把日期整理成 ISO-8601 格式 (YYYY-mm-dd)。

1.1 用 ```case``` 來做，```$1``` 代表輸入時的第一個參數，```$2``` 為第二個，以此類推。例如：
```sh
command a b
```
其中```$1``` 為 ```a```，而 ```$2``` 為 ```b```

1.2 用 sed 來取代字串，那些全形半形的空白很惱人，所以先把它們都除掉


```bash
cat > ./cleandata.sh << __EOF
#!/usr/bin/env sh

case "\$1" in
    "-c")
        # 取代半型空白
        sed -i ''  's/ //g' \$2
        # 取代全形空白
        sed -i ''  's/　//g' \$2
        echo "clean up done!"
        ;;
        
    "-d")
        # 把 YYYY/mm/dd 改成 ISO8601 格式(YYYY-mm-dd) 
        sed -i '' 's/\//-/g' \$2
        echo "substitution done!"
        ;;
        
    *)
        echo "Usage: cleandata.sh {-c|-d} filename"
        echo "清理資料，把全/半形空白取代並且整理日期為 ISO 8601 格式(YYYY-mm-dd)"
        ;;
esac
__EOF
```

    


```bash
./cleandata.sh -c ../data/cwb_current_station_list.csv
./cleandata.sh -d ../data/cwb_revoked_station_list.csv
```

    clean up done!
    substitution done!


## 2. 建立 postgresql Table


```bash
# 設定變數，資料庫名稱為 nvdimp
export DB="nvdimp"
# 用資料定義語言(Data definition language, DDL)來建立新的資料表(table)，資料表名稱為
cat > create_station_list_table.sql << _EOF

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
_EOF

# 建立資料表架構
# nvdimp 為資料庫名稱
psql -d ${DB} -f create_station_list_table.sql
```

    DROP TABLE
    CREATE TABLE


## 3. 餵資料進去 Table

因為欄位順序不太一樣，所以先把測站的代碼(```station_id```)丟進去


```bash
# 先處理現存測站
echo "BEGIN;" > insert_station_id_data.sql
awk -v q="'" -F'|' 'NR>1 { print "INSERT INTO cwb_station_list (station_id) VALUES (" q$1q ");"}' \
  ../data/cwb_current_station_list.csv >> insert_station_id_data.sql
echo "COMMIT;" >> insert_station_id_data.sql
# execute sql
psql -q -d ${DB} -f insert_station_id_data.sql
```

    

餵其他資料進去，這邊使用
```SQL
UPDATE _table_ SET _column_name_ = _value_;
```
來將資料更新進去


```bash
# 欄位的位置編號對照
# 站號|站名|海拔高度(M)|經度|緯度|城市|地址|資料起始日期|撤站日期|備註|原站號|新站號
#   1   2     3        4    5   6   7    8           9     10   11   12
# awk 中可以用 $number (number 為正整數) 代表欄位

echo "BEGIN;" > update_station_data.sql
awk -v q="'" -F '|' \
 'NR>1 { print "UPDATE cwb_station_list SET station=" q$2q \
  ", elevation = " $3 \
  ", longitude = " $4 \
  ", latitude = " $5 \
  ", county = " q$6q \
  ", address = " q$7q \
  ", establish_date = " q$8q \
  ", note = "q$10q " WHERE station_id=" q$1q ";"}' \
  ../data/cwb_current_station_list.csv >> update_station_data.sql
echo "COMMIT;" >> update_station_data.sql
# 執行
psql -q -d ${DB} -f update_station_data.sql
```

    

## 4. 建立空間屬性的欄位

接下來我們要把測站的經緯度建立具有空間屬性(spatial geometry)的資料表欄位，在上面 DDL 建立資料表時，已經建立了兩個欄位，```geom_wgs84``` 及 ```geom_twd97``` 兩個空間屬性欄位，分別是 WGS84 經緯度座標([EPSG:4326](http://spatialreference.org/ref/epsg/wgs-84/))以及臺灣使用的橫麥卡托投影二度分帶座標系統(即 TWD97 TM2 Zone 121, [EPSG:3826](http://spatialreference.org/ref/epsg/twd97-tm2-zone-121/)，以下使用 TWD97 來縮寫)。原始資料中提供的只有經緯度，為了方便之後的使用，所以我也同時轉換成 TWD97 的座標系統。

使用的 PostGIS function:

* [ST_SetSRID](http://postgis.net/docs/ST_SetSRID.html): 設定 SRID (spatial reference ID)
* [ST_MakePoint](http://postgis.net/docs/ST_MakePoint.html): 將 x, y 座標建立具空間屬性的點位
* [ST_Transform](http://postgis.net/docs/ST_Transform.html): 轉換不同的座標系統


同樣的我們使用```UPDATE```加上 subquery 來更新資料：

**<font style="color:red">注意:測站資料若是在外島，像是金門、馬祖要另外處理成 TWD97 TM2 zone 119 的投影座標系統，
在此先略過不提，但請記得這件事情</font> **


```bash
# 更新 geometry，先處理 WGS84
cat > set_srid.sql << _EOF
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
_EOF

# 執行上面的 set_srid.sql
psql -d ${DB} -f set_srid.sql
```

    BEGIN
    UPDATE 531
    COMMIT
    BEGIN
    UPDATE 531
    COMMIT


接下來你可以用 QGIS 來看顯示的座標對不對（略）

## 5. 轉成不同格式的檔案

我們可以把資料 dump 成 SQL，或是轉成 ESRI shapefile, json 等格式


```bash
# pg_dump
pg_dump -d ${DB} -O -t cwb_station_list > ../data/cwb_station_list.sql
```

    


```bash
# 轉成 ESRI Shapefile，分別轉成 wgs84 和 twd97 tm2 zone 121 
# 先建立 shp 資料夾，這樣才不會看起來一堆檔案亂七八糟
if [ ! -d ../data/shp ]; then
    mkdir ../data/shp
fi

pgsql2shp -f ../data/shp/cwb_station_list_wgs84 -g geom_wgs84 nvdimp public.cwb_station_list 
pgsql2shp -f ../data/shp/cwb_station_list_twd97 -g geom_twd97 nvdimp public.cwb_station_list 
```

    Initializing... 
    Done (postgis major version: 2).
    Output shape: Point
    Dumping: XXXXXX [531 rows].
    Initializing... 
    Done (postgis major version: 2).
    Output shape: Point
    Dumping: XXXXXX [531 rows].


## 參考資料：
[PostGIS manual](http://postgis.net/docs)
