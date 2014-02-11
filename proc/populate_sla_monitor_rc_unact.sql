set dateformat dmy;
exec calculate_sla_monitor_rc_unact '01.02.2013';--раньше не было итема в заббиксе
exec calculate_sla_monitor_rc_unact2 '01.02.2014';-- до 01.02.2014 сла считалось из monitor.unact.ru, после из monitor2.unact.ru
