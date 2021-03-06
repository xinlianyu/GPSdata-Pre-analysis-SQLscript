   
  -------------------------------------2. Overall behavioral analysis
select top 10000 * from [Taxi].[dbo].[qs01_sorted] where carid='00048' order by id_sorted

  --2.1 Overall pick up location, 412,379 in total
select b.id_sorted,b.carid,b.longitude,b.latitude,b.[GPSTIME],b.year,b.month,b.day,b.hour,b.min,b.sec,row_number() over(PARTITION BY b.carid order by b.[GPSTIME]) pickupid
into [Taxi].[dbo].[qs01_pickup]
from [Taxi].[dbo].[qs01_sorted] a, [Taxi].[dbo].[qs01_sorted] b
where a.carid=b.carid and a.id_sorted=b.id_sorted-1
and a.status='0' and b.status='1'
order by b.carid,b.[GPSTIME];
  --2.2 Overall dropoff location, 411,920 in total
select a.carid,a.id_sorted,a.longitude,a.latitude,a.[GPSTIME],a.year,a.month,a.day,a.hour,a.min,a.sec,row_number() over(PARTITION BY b.carid order by b.[GPSTIME]) dropoffid
into [Taxi].[dbo].[qs01_dropoff]
from [Taxi].[dbo].[qs01_sorted] a, [Taxi].[dbo].[qs01_sorted] b
where a.carid=b.carid and a.id_sorted=b.id_sorted-1
and a.status='1' and b.status='0';
--verified this is correct
--select * from [Taxi].[dbo].[qs01_pickup] where carid='10008' order by [GPSTIME];
--select * from [Taxi].[dbo].[qs01_dropoff] where carid='10008' order by [GPSTIME];
--select * from [Taxi].[dbo].[qs01_sorted] where carid='10008' order by [GPSTIME];

  --2.3 Identify trips, 392,641 in total
select a.carid,a.longitude pickuplon,a.latitude pickuplat,a.[GPSTIME] pickup_date_time,a.year pickupyear,a.month pickupmonth,a.day pickupday,a.hour pickuphour,a.min pickupmin,a.sec pickupsec,
b.longitude dropofflon,b.latitude dropofflat,b.[GPSTIME] dropoff_date_time,b.year dropoffyear,b.month dropoffmonth,b.day dropoffday,b.hour dropoffhour,b.min dropoffmin,b.sec dropoffsec,
b.hour*3600+b.min*60+b.sec-a.hour*3600-a.min*60-a.sec triptime
into qs01_trips_temp
from [Taxi].[dbo].[qs01_pickup] a, [Taxi].[dbo].[qs01_dropoff] b
where (a.carid=b.carid and a.pickupid=b.dropoffid and a.[GPSTIME]<=b.[GPSTIME])--vehicle started from empty,so pickupid=dropoffid
or
(a.carid=b.carid and a.pickupid=b.dropoffid-1 and a.[GPSTIME]<=b.[GPSTIME]);--vehicle started from occupied,so pickupid=dropoffid-1

--some trips have only one gps points, get rid of them
delete from qs01_trips_temp
where pickup_date_time = dropoff_date_time;

--the 'or' above may have overlap, pick the earliest arrival
select a.*,row_number() over(PARTITION BY b.carid order by b.pickup_date_time) tripid into [Taxi].[dbo].[qs01_trips] from 
qs01_trips_temp a,
(select carid,pickup_date_time,min(dropoff_date_time)min_dropoff_date_time from qs01_trips_temp
group by carid,pickup_date_time) b
where a.carid=b.carid and a.pickup_date_time=b.pickup_date_time and a.dropoff_date_time=b.min_dropoff_date_time;
--drop temp table
drop table qs01_trips_temp;

--and a.carid='10008' order by a.[GPSTIME] --verify with 10008 and 00033
/*trips for 10008
00:24:12-00:29:44
00:49:46-01:13:19
02:24:20-02:24:20
02:25:40-07:38:50
trips for 00033
08:42:21-09:48:04
10:10:03-10:10:04*/
  --2.4 Average duration of trip

/*SELECT pickuphour,count(*)
  FROM [Taxi].[dbo].[qs01_trips]
  group by pickuphour
  order by pickuphour*/

  --2.5 Average vacant time percentage, 407,211 in total
select a.carid,a.longitude startlon,a.latitude startlat,a.[GPSTIME] start_date_time,a.year startyear,a.month startmonth,a.day startday,a.hour starthour,a.min startmin,a.sec startsec,
b.longitude endlon,b.latitude endlat,b.[GPSTIME] end_date_time,b.year endyear,b.month endmonth,b.day endday,b.hour endhour,b.min endmin,b.sec endsec,
b.hour*3600+b.min*60+b.sec-a.hour*3600-a.min*60-a.sec searchtime
into qs01_searches_temp
from [Taxi].[dbo].[qs01_dropoff] a, [Taxi].[dbo].[qs01_pickup] b
where (a.carid=b.carid and b.pickupid=a.dropoffid and a.[GPSTIME]<=b.[GPSTIME])--vehicle started from occupied,so pickupid=dropoffid
or 
(a.carid=b.carid and b.pickupid=a.dropoffid+1 and a.[GPSTIME]<=b.[GPSTIME]);--vehicle started from empty,so pickupid=dropoffid+1
--some searches have only one gps points, get rid of them
delete from qs01_searches_temp
where start_date_time = end_date_time;
--the 'or' above may have overlap, pick the earliest arrival
select a.*,row_number() over(PARTITION BY b.carid order by b.start_date_time) searchid into [Taxi].[dbo].qs01_searches from 
qs01_searches_temp a,
(select carid,start_date_time,min(end_date_time)min_end_date_time from qs01_searches_temp
group by carid,start_date_time) b
where a.carid=b.carid and a.start_date_time=b.start_date_time and a.end_date_time=b.min_end_date_time;
--drop temp table
drop table qs01_searches_temp;
/*searches for 10008
00:03:00-00:24:12
00:29:44-00:49:46
01:13:19-02:24:20
02:24:20-02:25:40
07:38:50-09:12:57
searches for 00033
09:48:04-10:10:03
*/

  --2.6 driver types
 /* select a.*,b.nooperationtime
   into  [qs01_drivers_temp2] from
   [qs01_drivers_temp] a
  left join
  (select a.carid,count(*)*300 nooperationtime from
	(SELECT carid,[timeindex5],max(speed) max_speed,max(status) max_status
    FROM [Taxi].[dbo].[qs01_sorted]
	group by carid,timeindex5) a 
where cast(a.max_speed as float)=0.0 --and cast(a.max_status as float)=0.0 
group by a.carid) b
	on a.carid=b.carid*/

	select a.carid,timeindex5 
	into taxi.dbo.[qs01_timeindex_notinoperation] from
	(SELECT carid,[timeindex5],max(speed) max_speed
    FROM [Taxi].[dbo].[qs01_sorted]
	group by carid,timeindex5) a 
where cast(a.max_speed as float)=0.0 
order by carid, timeindex5

select c.carid,c.tripid invalid_tips 
into [taxi].[dbo].[qs01_invalid_trips] from (
select * from (
select a.carid,a.tripid,count(b.timeindex5) num_timeindex_notinoperation
from [Taxi].[dbo].[qs01_trips] a, taxi.dbo.[qs01_timeindex_notinoperation] b
where a.carid=b.carid and a.pickuphour*12+a.pickupmin/5 <=b.timeindex5 and a.dropoffhour*12+a.dropoffmin/5>=b.timeindex5
group by a.carid,a.tripid) b
where b.num_timeindex_notinoperation>=5) c

select c.carid,c.searchid invalid_search
into taxi.dbo.qs01_invalid_searches from(
select * from (
select a.carid,a.searchid,count(b.timeindex5) num_timeindex_notinoperation
from [Taxi].[dbo].[qs01_searches] a, taxi.dbo.[qs01_timeindex_notinoperation] b
where a.carid=b.carid and a.starthour*12+a.startmin/5 <=b.timeindex5 and a.endhour*12+a.endmin/5>=b.timeindex5
group by a.carid,a.searchid) b
where b.num_timeindex_notinoperation>=5)c

select * into taxi.dbo.qs01_trips2 
from taxi.dbo.qs01_trips

delete a
from taxi.dbo.qs01_trips2 a
join taxi.dbo.qs01_invalid_trips b 
on a.carid=b.carid and a.tripid=b.invalid_tips

select * into taxi.dbo.qs01_searches2 
from taxi.dbo.qs01_searches

delete a
from taxi.dbo.qs01_searches2 a
join taxi.dbo.qs01_invalid_searches b 
on a.carid=b.carid and a.searchid=b.invalid_search

select a.*,b.totalvacant,b.totalsearches,a.totaloccupied+b.totalvacant totalopstime,cast(a.totaloccupied as float)/(a.totaloccupied+b.totalvacant) occupiedrate
into taxi.dbo.qs01_driversnew
 from 
(select carid,sum(triptime) totaloccupied,count(tripid) totaltrips
from taxi.dbo.qs01_trips2
group by carid) a,
(select carid,sum(searchtime) totalvacant,count(searchid) totalsearches
from taxi.dbo.qs01_searches2
group by carid) b
where a.carid=b.carid
order by occupiedrate

	--and substring(c.opsend,12,2)*3600+substring(c.opsend,15,2)*60+substring(c.opsend,18,2)-substring(c.opsstart,12,2)*3600-substring(c.opsstart,15,2)*60-substring(c.opsstart,18,2)>0;

--	select top 10 * from [Taxi].[dbo].[qs01_drivers] where carid='27560'
  --2.6.1 based on vacant time percentage
  --2.6.2 based on time in operation

  --2.7 average speed for two status at midnight
select a.carid,a.aveSpeedStatus0,b.aveSpeedStatus1 from
(select carid,avg(CAST(speed as float)) aveSpeedStatus0
from [Taxi].[dbo].[qs01] where status='0' and hour='02'
group by carid) a,
(select carid,avg(CAST(speed as float)) aveSpeedStatus1
from [Taxi].[dbo].[qs01] where status='1'  and hour='02'
group by carid) b
where a.carid=b.carid



  ---------------------------------------3 case study
/*
1. Spatial concentration: model the competition 
2. Various type of driver behavior, characteristic and outcomes;
3. Hot-spot taxi behavior analysis, focus group and comparison with others 
4. Individual driver case study, pick up and drop off location, and repeatness analysis; 
5. Policy overlap degree, gain, next day policy change correlation. 
6. Calibrate demand, land use? Special location such as hospital, statdium activity pattern and story behind it. 
7. Cruise time fluctuation; area repeat possibility;
8. Reject model: spatial location, time close; really close, stopped first but didn't pick up; 
9. Randomness in passengers 
*/
SELECT TOP 1000 [carid]
      ,[timeOccupied]
      ,[totaltrips]
      ,[timeVacant]
      ,[totalsearches]
      ,[opsstart]
      ,[opsend]
      ,[opstime]
      ,[opspercentage]
  FROM [Taxi].[dbo].[qs01_driversnew]
  where carid in (10778,18046,13600,28127,25590)
/*
3.1 calculate number of valid trips for each driver, and select case study objectives 
valid trip: defined as travel time higher than 5 mins.
Efficient drivers, defined as those who have highest time occupied. Focus on those with frequent pickups with short trips: 
10778,18046,13600,28127,25590,14270,23388, 28095,14391,11186,13539,23551,20558,17192,20970,13033,22071
	- carid 13600, 27 trip, operation time 86,377 seconds, timeOccupied 61,398 (71%)
	- carid 10778, 22 trip, operation time 86,382 seconds, timeOccupied 61,498 (71%)
	- carid 28127, 24 trip, operation time 86,393 seconds, timeOccupied 61,384 (71%)
	- carid 25590, 19 trip, operation time 86,025 seconds, timeOccupied 61,363 (71%)
	- carid 18046, 13 trip, operation time 86,379 seconds, timeOccupied 61,421 (71%)
Unlucky drivers: 
	- carid 11594, 11 trip, operation time 26,041 seconds, timeOccupied 3,555 (14%)
	- carid 11582, 25 trip, operation time 44,545 seconds, timeOccupied 15,073 (34%) 
	- carid 11590, 16 trip, operation time 35,986 seconds, timeOccupied 15,113 (41%)
	- carid 23632, 31 trip, operation time 46,623 seconds, timeOccupied 15,095 (32%) 
	- carid 25678, 27 trip, operation time 39,039 seconds, timeOccupied 15,125 (39%)
Average drivers: 10 trips. 25857(3787 gps points), 10248(4100 gps points), 10705(4198 gps points)
*/
select a.* from
(SELECT *
  FROM [Taxi].[dbo].[qs01_driversnew]
  where totalopstime>=3600*10 --operate more than 10 hours
  and totaltrips>=24*0.1 and totaltrips<=24*4 -- have at least 5 pickups to avoid all-time long trip which may be caused by drivers forgot to turn off device but not in operation
  and totaloccupied>=totalopstime*0.1 and totaloccupied<=totalopstime*0.9 --to avoid all-time long trip which may be caused by drivers forgot to turn off device but not in operation
  and totalvacant>=totalopstime*0.1 and totalvacant<=totalopstime*0.7 -- to avoid all-time long search which may be caused by drivers forgot to turn off device but not in operation
  --and carid in ('13142', '16851', '10575', '26240','10316','15586')
  )a,
(select carid, count(distinct hour) drivinghours
	from [Taxi].[dbo].[qs01_sorted]
	where cast(speed as float)>10.0
	group by carid) b
	where a.carid=b.carid and b.drivinghours>=11
	order by occupiedrate desc
	--order by  a.timeOccupied desc,a.totaltrips desc

--efficient: 17789,16851,30002,16952,15412,16573,13291,26214,17108,13258
--unlucky: 27135,27652,25994,16825,25179,10712,25627,13449
select *,hour+':'+min time
  FROM [Taxi].[dbo].[qs01_sorted]
  where carid='15412'
  order by GPSTIME

SELECT *,hour+':'+min time
  FROM [Taxi].[dbo].[qs01_pickup]
  where carid='27135'
  order by GPSTIME

SELECT *,hour+':'+min time
  FROM [Taxi].[dbo].[qs01_dropoff]
  where carid='27135'
  order by GPSTIME

SELECT *,starthour+':'+startmin time,'LINESTRING('+startlon+' '+startlat+','+ endlon +' '+ endlat+')' searches
  FROM [Taxi].[dbo].[qs01_searches]
  where carid='27135'
  order by start_date_time

SELECT *,pickuphour+':'+pickupmin time,'LINESTRING('+pickuplon+' '+pickuplat+','+ dropofflon +' '+ dropofflat+')' trips
  FROM [Taxi].[dbo].[qs01_trips]
  where carid='27135'
  order by pickup_date_time