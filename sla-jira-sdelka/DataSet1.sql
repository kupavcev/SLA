SELECT 
	--j.id,
	distinct j.pkey,
	t.pname AS 'Type',
	s.pname AS 'Status',
	j.created AS 'Created',
	g.created AS 'Closed',
	j.DUEDATE AS 'Due date',
	j.REPORTER,
	--j2.pkey,
	DATEDIFF(dd, j.DUEDATE, g.CREATED) -- DATEDIFF(wk, j.DUEDATE, g.CREATED) * 2 AS 'Days Of Delayed'
	,CASE 
		WHEN (DATEDIFF(dd, j.DUEDATE, g.CREATED) <= 0) THEN 50 
		WHEN (DATEDIFF(dd, j.DUEDATE, g.CREATED) > 0) THEN -500
	END AS IssuePrice,
	j.ASSIGNEE,
	j.SUMMARY
FROM [JIRA].[jira].[jiraissue] j
	JOIN jira.jira.changegroup g on j.ID=g.issueid --история изменений
	JOIN jira.jira.changeitem i on g.ID=i.groupid  --история изменений         
    JOIN jira.jira.nodeassociation n on j.id = n.source_node_id --компоненты
    JOIN jira.jira.issuetype t on j.issuetype = t.ID --тип запроса
    JOIN jira.jira.issuestatus s on j.issuestatus = s.ID --статус
WHERE
     g.CREATED BETWEEN @startPeriod AND @endPeriod 
     AND i.newvalue LIKE '5' -- время статуса закрыт
     AND (j.issuetype=38
     OR j.issuetype=32)
     AND j.project=10070
     AND j.RESOLUTION=1
     --AND j.issuestatus=6 --статус закрыт
	--and (DATEDIFF(dd, j.DUEDATE, g.CREATED) - DATEDIFF(wk, j.DUEDATE, g.CREATED) * 2 > 0)
	and j.pkey not in ('INFR-12134','INFR-11157','INFR-8686','INFR-12393','INFR-12418','INFR-12403','INFR-8223')
	--and DATEDIFF(dd, j.DUEDATE, g.CREATED) > 0
	and j.ASSIGNEE = @username
ORDER BY j.pkey
