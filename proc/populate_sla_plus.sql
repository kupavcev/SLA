declare @ddateb datetime, @ddatee datetime, @ddatei datetime,@comp varchar(150), @i int;
set dateformat dmy;
set @ddateb='01.01.2013';
set @ddatee=DATEADD(month, DATEDIFF(month, 0, getdate()+1), 0);
create table #tmp(date_uid datetime,person_uid int,issuetype_uid varchar(200),bonustype_uid int,bonus float,issueid bigint) 
create table #sla_owner(id int identity(1,1) not null,component_info varchar(150));
insert into #sla_owner(component_info)
select distinct component_info from sla_owner where sla_type=1;
set @ddatei=@ddateb;
while @ddatei<@ddatee begin
	set @i=1;
	while @i<=(select max(id) from #sla_owner) begin
 		set @comp=(select component_info from #sla_owner where id=@i);
		insert into #tmp
		exec calculate_sla_plus @ddatei,@comp;
		set @i=@i+1;
	end
	set @ddatei=dateadd(month,1,@ddatei);
	--print @ddatei;
end

select * from #tmp;
drop table #tmp;
drop table #sla_owner;
