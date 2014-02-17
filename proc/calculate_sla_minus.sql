alter procedure calculate_sla_minus(@month datetime,@component varchar(150))
as
begin
declare @ddateb datetime, @ddatee datetime, @dcomponent nvarchar(150), @sla_type int;
set dateformat dmy;
set @ddateb=DATEADD(month, DATEDIFF(month, 0, @month), 0)--'01.10.2013';
set @ddatee=DATEADD(month, DATEDIFF(month, 0, @month)+1, 0);--'01.11.2013';
set @dcomponent=@component;--'Рабочие станции';
set @sla_type=0;

select 
        jira.jiraissue.id,
        jira.jiraissue.pkey,
        jira.jiraissue.summary,
        jira.jiraissue.priority,
        (select STRINGVALUE from jira.customfieldvalue where customfield=10510 and issue=jira.jiraissue.id) as Otv,
        jira.jiraissue.created,
        jira.component.id as component
        
into #sla_issue 
from jira.jiraissue
join jira.nodeassociation on jira.nodeassociation.SOURCE_NODE_ID=jira.jiraissue.id
join jira.component on jira.component.id=jira.nodeassociation.SINK_NODE_ID
where 
jira.jiraissue.issuetype=(select id from jira.issuetype where pname='Инцидент')and
jira.component.cname=@dcomponent and jira.nodeassociation.ASSOCIATION_TYPE='IssueComponent'and 
isnull(jira.jiraissue.resolution,0)<>2

select #sla_issue.id, jira.changegroup.created as ddate, cast(newvalue as varchar) as state into #sla_issue_step from #sla_issue
join jira.changegroup on jira.changegroup.issueid=#sla_issue.id
join jira.jira.changeitem on jira.changeitem.groupid=jira.changegroup.id
where FIELD='status' 

delete #sla_issue_step where state not in('1','5');

--Закрытые до @ddateb
delete from #sla_issue
where (select max(ddate) from #sla_issue_step where #sla_issue.id=#sla_issue_step.id and #sla_issue_step.state='5')<@ddateb

delete from #sla_issue_step where #sla_issue_step.id not in(select id from #sla_issue);
--
--Впервые открытые после @ddatee

delete from #sla_issue
where (select min(ddate) from #sla_issue_step where #sla_issue.id=#sla_issue_step.id and #sla_issue_step.state='1')>=@ddatee

delete from #sla_issue_step where #sla_issue_step.id not in(select id from #sla_issue);

--
select         *,(select count(*) from #sla_issue_step slave where slave.ddate<=main.ddate and slave.id=main.id) as numb
into #sla_issue_step_numb
from #sla_issue_step main
--Дублирующиеся step`ы
delete main from #sla_issue_step_numb as main
where exists(select * from #sla_issue_step_numb slave where slave.id=main.id and main.numb-1=slave.numb and slave.state=main.state)
--

--step`ы вне диапазона
delete from #sla_issue_step_numb where ddate not between @ddateb and @ddatee
--

-- добавляем недостающие step`ы
insert into #sla_issue_step_numb
select isnull(id,0),@ddatee,5,999 from #sla_issue_step_numb main where 
numb =(select max(numb) from #sla_issue_step_numb slave where main.id=slave.id group by id) and state=1

insert into #sla_issue_step_numb values(
        isnull((select id from #sla_issue_step_numb main where numb=1 and state=5),0),
        @ddateb,
        1,
        0)
--

select         main.id,
        main.pkey as [pkey],
        main.summary as [summary],
        (select pname from jira.priority where jira.priority.id=main.priority) as [pname],
        isnull((select sum(DATEDIFF(n, CAST('00:00' AS DATETIME), ddate)) from #sla_issue_step_numb slave where main.id=slave.id and state=5),DATEDIFF(n, CAST('00:00' AS DATETIME), @ddatee)) -
        isnull((select sum(DATEDIFF(n, CAST('00:00' AS DATETIME), ddate)) from #sla_issue_step_numb slave where main.id=slave.id and state=1),DATEDIFF(n, CAST('00:00' AS DATETIME), @ddateb)) as [InWork(minutes)],
        main.otv,
        main.created,
        (select factor from dbo.sla_factor where dbo.sla_factor.component_id=main.component
                and dbo.sla_factor.priority_id=main.priority) as [Factor],
	component
into #rep
from #sla_issue main order by otv,id

select         *, 
        isnull((select numbervalue from jira.customfieldvalue where issue=#rep.id and customfield=11020),[Factor]*[InWork(minutes)])as ti,
        [Factor]*[InWork(minutes)] as k
         into #rep1 from #rep;

declare @Q float, @a float, @b float;
set @a=isnull((select factor from dbo.sla_factor where dbo.sla_factor.component_id=(select id from jira.component where cname=@dcomponent) and dbo.sla_factor.priority_id=996),0);
set @b=isnull((select factor from dbo.sla_factor where dbo.sla_factor.component_id=(select id from jira.component where cname=@dcomponent) and dbo.sla_factor.priority_id=995),0);

--select factor from dbo.sla_factor where dbo.sla_factor.component_id=(select id from jira.component where cname='Резервное копирование') and dbo.sla_factor.priority_id=996
--select * from sla_factor where component_id=10209

set @Q=(select sum(ti) from #rep1);
set @Q=1-(@Q/43200);

declare @sla_owner_count int;
set @sla_owner_count=isnull((select count(*) from sla_owner where sla_type=@sla_type and sla_owner.component_info=@dcomponent),1);

if @sla_owner_count=0 set @sla_owner_count=1;

select distinct @ddateb as date_uid,
		sla_owner.owner as person_uid,
		'type of: month bonus' as issuetype_uid,
		20 as bonustype_uid,
		(@a+@b)/@sla_owner_count as bonus,
		-1 as issueid
	from sla_owner where sla_type=@sla_type and sla_owner.component_info=@dcomponent 
	union all
select 		isnull((select max(#sla_issue_step_numb.ddate) from #sla_issue_step_numb where #sla_issue_step_numb.id=#rep1.id and #sla_issue_step_numb.state=5),-1) as date_uid,
		sla_owner.owner as person_uid,
		'type of:'+pkey as issuetype_uid,
		20 as bonustype_uid,
		-(@a+@b-((1-ti/43200)*@a+@b))/@sla_owner_count as bonus,
		id as issueid
	from #rep1
	join sla_owner on sla_type=@sla_type and sla_owner.component_id=component

drop table #rep1;
drop table #rep;
drop table #sla_issue;
drop table #sla_issue_step;
drop table #sla_issue_step_numb;
end
