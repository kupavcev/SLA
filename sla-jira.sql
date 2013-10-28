declare @ddateb datetime, @ddatee datetime;
declare @dcomponent varchar(50)

set @dcomponent='КСПД'--'Резервное копирование'--'Wifi';--'Adaptive Server Anywhere - rc_unact'--
set @ddateb='2012-04-01';
set @ddatee='2012-05-01';

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
jira.jiraissue.resolution<>2

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
select 	*,(select count(*) from #sla_issue_step slave where slave.ddate<=main.ddate and slave.id=main.id) as numb
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

select 	main.id,
	main.pkey as [pkey],
	main.summary as [summary],
	(select pname from jira.priority where jira.priority.id=main.priority) as [pname],
	isnull((select sum(DATEDIFF(n, CAST('00:00' AS DATETIME), ddate)) from #sla_issue_step_numb slave where main.id=slave.id and state=5),DATEDIFF(n, CAST('00:00' AS DATETIME), @ddatee)) -
	isnull((select sum(DATEDIFF(n, CAST('00:00' AS DATETIME), ddate)) from #sla_issue_step_numb slave where main.id=slave.id and state=1),DATEDIFF(n, CAST('00:00' AS DATETIME), @ddateb)) as [InWork(minutes)],
	main.otv,
	main.created,
	(select factor from dbo.sla_factor where dbo.sla_factor.component_id=main.component
		and dbo.sla_factor.priority_id=main.priority) as [Factor]
from #sla_issue main order by otv,id

drop table #sla_issue;
drop table #sla_issue_step;
drop table #sla_issue_step_numb;
/*
select * from #sla_issue
select * from #sla_issue_step_numb where id=209891
*/