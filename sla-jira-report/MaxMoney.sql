select isnull((select factor from dbo.sla_factor where dbo.sla_factor.component_id=(select id from jira.component where cname=@dcomponent) and dbo.sla_factor.priority_id=996),0)+
isnull((select factor from dbo.sla_factor where dbo.sla_factor.component_id=(select id from jira.component where cname=@dcomponent) and dbo.sla_factor.priority_id=995),0)
