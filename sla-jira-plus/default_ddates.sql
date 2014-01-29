select 	CAST(dateadd(day,1-day(getdate()),getdate()) AS DATE) as def_ddatee,
	dateadd(month,-1,CAST(dateadd(day,1-day(getdate()),getdate()) AS DATE))as def_ddate
