alter procedure calculate_sla_fix(@month datetime, @component varchar(150))
as
begin
declare @ddateb datetime, @ddatee datetime, @dcomponent nvarchar(150), @sla_type int;
set dateformat dmy;
set @ddateb=DATEADD(month, DATEDIFF(month, 0, @month), 0)--'01.10.2013';
set @ddatee=DATEADD(month, DATEDIFF(month, 0, @month)+1, 0);--'01.11.2013';
set @dcomponent=@component;--'Рабочие станции';
set @sla_type=3;
declare @comp int;
set @comp=(select component_id from sla_owner where component_info like @dcomponent and sla_type=@sla_type);
declare @sla_owner_count int;
set @sla_owner_count=(select count(*) from sla_owner where sla_type=@sla_type and component_id=@comp);

if @sla_owner_count=0 set @sla_owner_count=1;

select  	@ddateb as date_uid,
		owner as person_uid,
		'type of: month bonus' as issuetype_uid,
		22 as bonustype_uid,
		(select factor/@sla_owner_count from sla_factor where component_id=@comp and priority_id=1000) as bonus,
		-1 as issueid
		from sla_owner where component_id=@comp and sla_type=@sla_type
end
