    -------------------------------------0. Preprocess
  --0.0 check values in the table
   select * from [taxi].[dbo].[apr02] where carid=00002

   USE AdventureWorks
   GO
   sp_RENAME '[taxi].[dbo].[apr02].[carid]', 'car' , 'COLUMN'
   GO
   sp_RENAME '[taxi].[dbo].[apr02].[Column 1]', 'warning' , 'COLUMN';
   sp_RENAME '[taxi].[dbo].[apr02].[Column 2]', 'status' , 'COLUMN';	
   sp_RENAME '[taxi].[dbo].[apr02].[Column 3]', 'light' , 'COLUMN';	
   sp_RENAME '[taxi].[dbo].[apr02].[Column 4]', 'overpass' , 'COLUMN';	
   sp_RENAME '[taxi].[dbo].[apr02].[Column 5]', 'brake' , 'COLUMN';
   sp_RENAME '[taxi].[dbo].[apr02].[Column 6]', 'receivedtime' , 'COLUMN';
   sp_RENAME '[taxi].[dbo].[apr02].[Column 7]', 'gpstime' , 'COLUMN';	
   sp_RENAME '[taxi].[dbo].[apr02].[Column 8]', 'longitude' , 'COLUMN';	
   sp_RENAME '[taxi].[dbo].[apr02].[Column 9]', 'latitude' , 'COLUMN';
   sp_RENAME '[taxi].[dbo].[apr02].[Column 10]', 'speed' , 'COLUMN';
   sp_RENAME '[taxi].[dbo].[apr02].[Column 11]', 'direction' , 'COLUMN';	
   sp_RENAME '[taxi].[dbo].[apr02].[Column 12]', 'satellite' , 'COLUMN';	
	GO

   select top 10000* from [taxi].[dbo].[apr02_triprecords]

  -- 0.1 Add additional columns for date and time
   alter table [taxi].[dbo].[apr02]
   add year char(4),
	month char(2),
	day char(2),
	hour char(2),
	min char(2),
	sec char(2),
	datetime varchar(50);


--0.2 modify values for those new columns
  update [taxi].[dbo].[apr02]
  set  year=substring([gpstime],1,4),
	month=substring([gpstime],6,2), 
	day=substring([gpstime],9,2), 
	hour=substring([gpstime],12,2),
	min=substring([gpstime],15,2),
	sec=substring([gpstime],18,2),
    datetime =year+month+day+hour+min+sec;


 --0.3 sort according to carid, [gpstime], note that choose year=2015 and month=4 and day=2, give each record a unique sored id
 select a.id_sorted,a.[carid],a.[status],a.[gpstime],a.[longitude],a.[latitude],a.[speed],a.[direction],a.year,a.month,a.day,a.hour,a.min,a.sec
  into [taxi].[dbo].[apr02_idsorted] from (
 select row_number() over(order by carid,[gpstime]) as id_sorted, *
 from [taxi].[dbo].[apr02] 
 where year=2015 and month=4 and day=2  -- or delete records not on this day
 )a
 

--0.4 identify trips 
select count(*) FROM  [taxi].[dbo].[apr02_idsorted]
select count(*) FROM  [taxi].[dbo].[apr02_idsorted] where status=1
select count(*) FROM  [taxi].[dbo].[apr02_idsorted] where status=0

---0.41 add a new column LagSTATUS
------Leed/lag function in SQL: 
------http://www.databasejournal.com/features/mssql/lead-and-lag-functions-in-sql-server-2012.html
SELECT  id_sorted, carid,gpstime,longitude,latitude,speed,direction,status as currentstatus,
LAG(status, 1, 'NA') 
        OVER (PARTITION BY  carid  ORDER BY  gpstime ASC)   AS lagstatus
into [taxi].[dbo].[apr02_idsorted_lag]
FROM  [taxi].[dbo].[apr02_idsorted]
order by id_sorted;

--0.42 choose the pick up and drop off records
select *  into [taxi].[dbo].[apr02_trip]
from [taxi].[dbo].[apr02_idsorted_lag]
where ( currentstatus='1' and lagstatus='0')--vehicle started from empty,so pickupid=dropoffid
or 
( currentstatus='0'and lagstatus='1')
order by id_sorted;--vehicle started from occupied,so pickupid=dropoffid-1
----select  * FROM  [ShanghaiTaxi].[dbo].[qs01_lag]  where LagSTATUS='NA

select * from taxi.dbo.apr02_trip where carid='10008' order by [gpstime]; 
select count(*)   FROM taxi.dbo.apr02_idsorted;  
select count(*)   FROM taxi.dbo.apr02_idsorted_lag; 
select count(*)   FROM taxi.dbo.apr02_trip;

--0.43 add lag(location) and lag(date_time) columns
SELECT  id_sorted,carid,speed,direction,currentstatus,lagstatus,gpstime as currentgpstime, 
LAG(gpstime, 1, 'NA') 
        OVER (PARTITION BY  carid  ORDER BY  gpstime ASC)   AS laggpstime,
longitude as currentlongitude, 
LAG(longitude, 1, 'NA') 
        OVER (PARTITION BY  carid  ORDER BY  gpstime ASC)   AS laglongitude,
latitude as currentlatitude,
LAG(latitude, 1, 'NA') 
        OVER (PARTITION BY  carid  ORDER BY  gpstime ASC)   AS laglatitude
INTO  [taxi].[dbo].[apr02_triprecords]
FROM  [taxi].[dbo].[apr02_trip];


--0.5  For each carid, select the row containing min/max(gpstime) and min/max(status) 
--0.51 a new table with min/max(gpstime) and min/max(status) for each id
Select * From taxi.dbo.apr02_idsorted
Inner Join
(
  Select carid,min(gpstime) mingpstime, max(gpstime) maxgpstime 
  from taxi.dbo.apr02_idsorted Group By carid
)t
On t.carid = taxi.dbo.apr02_idsorted.carid
Where t.mingpstime = taxi.dbo.apr02_idsorted.gpstime or t.maxgpstime=taxi.dbo.apr02_idsorted.gpstime;


--0.52   full join with [taxi].[dbo].[apr02_triprecords]
Select * From taxi.dbo.apr02_triprecords
full Join
(
  Select id_sorted,mingpstime,maxgpstime,status   from taxi.dbo.apr02_minmaxtime Group By carid
)b
On b.carid = taxi.dbo.apr02_triprecords.carid
order by id_sorted;


SELECT * FROM taxi.dbo.apr02_triprecords
LEFT JOIN 
( select id_sorted, from taxi.dbo.apr02_minmaxtime)b
ON b.id_sorted=taxi.dbo.apr02_triprecords.id_sorted 
order by taxi.dbo.apr02_triprecords.id_sorted;




--0.6 checek whether each car starts working at status=0
----0.61  For each id, select the row containing the minimum date_time
Select * From ShanghaiTaxi.dbo.taxi
Inner Join
(
  Select CARID,MIN(DATE_TIME) MinDATE_TIME From ShanghaiTaxi.dbo.taxi Group By CARID
)t
On t.CARID=ShanghaiTaxi.dbo.taxi.CARID
Where t.MinDATE_TIME=ShanghaiTaxi.dbo.taxi.DATE_TIME;

------0.62 pick examples, check the starting status
SELECT * FROM [ShanghaiTaxi].[dbo].[taxi] where CARID= '00142' ORDER BY DATE_TIME;
SELECT * FROM [ShanghaiTaxi].[dbo].[taxi] where CARID= '00144' ORDER BY DATE_TIME;
SELECT * FROM [ShanghaiTaxi].[dbo].[taxi] where CARID= '00146' ORDER BY DATE_TIME;


