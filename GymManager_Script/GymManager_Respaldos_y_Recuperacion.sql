--GYMMANAGER - RESPALDOS, SQL SERVER AGENT Y RESTAURACIÓN

-- PARTE 1. MODELO DE RECUPERACIÓN
use master;
go
alter database GymManager set recovery full;
go

-- PARTE 2. CREACIÓN DE JOBS (solo si no existen)
use msdb;
go

-- JOB FULL: domingo a las 00:00.
if not exists (select 1 from dbo.sysjobs where name = N'GymManager_Backup_Full')
begin
    exec dbo.sp_add_job
        @job_name = N'GymManager_Backup_Full',
        @enabled = 1,
        @description = N'Respaldo completo semanal de GymManager';

    exec dbo.sp_add_jobstep
        @job_name = N'GymManager_Backup_Full',
        @step_name = N'Respaldo FULL',
        @subsystem = N'TSQL',
        @database_name = N'master',
        @command = N'declare @archivo nvarchar(4000) = N''/backup/GymManager/Full/GymManager_FULL_'' + convert(char(8), getdate(), 112) + N''_'' + replace(convert(char(8), getdate(), 108), '':'', '''') + N''.bak''; backup database GymManager to disk = @archivo with checksum, compression, stats = 10;';

    exec dbo.sp_add_schedule
        @schedule_name = N'GymManager_Full_Domingo_0000',
        @enabled = 1,
        @freq_type = 8,
        @freq_interval = 1,
        @freq_recurrence_factor = 1,
        @active_start_time = 000000;

    exec dbo.sp_attach_schedule
        @job_name = N'GymManager_Backup_Full',
        @schedule_name = N'GymManager_Full_Domingo_0000';
    exec dbo.sp_add_jobserver @job_name = N'GymManager_Backup_Full';
end;
go

-- JOB DIFFERENTIAL: lunes a sábado a las 00:00 
if not exists (select 1 from dbo.sysjobs where name = N'GymManager_Backup_Differential')
begin
    exec dbo.sp_add_job
        @job_name = N'GymManager_Backup_Differential',
        @enabled = 1,
        @description = N'Respaldo diferencial de GymManager de lunes a sábado';

    exec dbo.sp_add_jobstep
        @job_name = N'GymManager_Backup_Differential',
        @step_name = N'Respaldo diferencial',
        @subsystem = N'TSQL',
        @database_name = N'master',
        @command = N'declare @archivo nvarchar(4000) = N''/backup/GymManager/Differential/GymManager_DIFF_'' + convert(char(8), getdate(), 112) + N''_'' + replace(convert(char(8), getdate(), 108), '':'', '''') + N''.bak''; backup database GymManager to disk = @archivo with differential, checksum, compression, stats = 10;';

    exec dbo.sp_add_schedule
        @schedule_name = N'GymManager_Diff_Lunes_Sabado_0000',
        @enabled = 1,
        @freq_type = 8,
        @freq_interval = 126,
        @freq_recurrence_factor = 1,
        @active_start_time = 000000;

    exec dbo.sp_attach_schedule
        @job_name = N'GymManager_Backup_Differential',
        @schedule_name = N'GymManager_Diff_Lunes_Sabado_0000';
    exec dbo.sp_add_jobserver @job_name = N'GymManager_Backup_Differential';
end;
go

-- JOB LOG: cada hora.
if not exists (select 1 from dbo.sysjobs where name = N'GymManager_Backup_Log')
begin
    exec dbo.sp_add_job
        @job_name = N'GymManager_Backup_Log',
        @enabled = 1,
        @description = N'Respaldo del log de transacciones de GymManager cada hora';

    exec dbo.sp_add_jobstep
        @job_name = N'GymManager_Backup_Log',
        @step_name = N'Respaldo LOG',
        @subsystem = N'TSQL',
        @database_name = N'master',
        @command = N'declare @archivo nvarchar(4000) = N''/backup/GymManager/Log/GymManager_LOG_'' + convert(char(8), getdate(), 112) + N''_'' + replace(convert(char(8), getdate(), 108), '':'', '''') + N''.trn''; backup log GymManager to disk = @archivo with checksum, compression, stats = 10;';

    exec dbo.sp_add_schedule
        @schedule_name = N'GymManager_Log_Cada_Hora',
        @enabled = 1,
        @freq_type = 4,
        @freq_interval = 1,
        @freq_subday_type = 8,
        @freq_subday_interval = 1,
        @active_start_time = 003000,
        @active_end_time = 235959;

    exec dbo.sp_attach_schedule
        @job_name = N'GymManager_Backup_Log',
        @schedule_name = N'GymManager_Log_Cada_Hora';
    exec dbo.sp_add_jobserver @job_name = N'GymManager_Backup_Log';
end;
go

-- PARTE 3. CONSULTAR JOBS, CALENDARIOS E HISTORIAL
select j.name as Trabajo, j.enabled as Habilitado, s.name as Calendario,
       s.enabled as CalendarioHabilitado, s.freq_type, s.freq_interval,
       s.freq_subday_type, s.freq_subday_interval, s.active_start_time
from msdb.dbo.sysjobs as j
left join msdb.dbo.sysjobschedules as js on js.job_id = j.job_id
left join msdb.dbo.sysschedules as s on s.schedule_id = js.schedule_id
where j.name like N'GymManager_Backup_%'
order by j.name;
go

select j.name as Trabajo, h.step_id, h.step_name, h.run_status,
       h.run_date, h.run_time, h.message
from msdb.dbo.sysjobs as j
inner join msdb.dbo.sysjobhistory as h on h.job_id = j.job_id
where j.name like N'GymManager_Backup_%'
order by h.instance_id desc;
go

-- PARTE 4. EJECUCIÓN MANUAL DE PRUEBA (cada llamada por separado).
exec msdb.dbo.sp_start_job @job_name = N'GymManager_Backup_Full';
exec msdb.dbo.sp_start_job @job_name = N'GymManager_Backup_Differential';
exec msdb.dbo.sp_start_job @job_name = N'GymManager_Backup_Log';

-- PARTE 5. RESPALDOS REGISTRADOS EN MSDB
select backupset.database_name, backupset.type as Tipo,
       backupset.backup_start_date, backupset.backup_finish_date,
       backupmediafamily.physical_device_name as Archivo
from msdb.dbo.backupset as backupset
inner join msdb.dbo.backupmediafamily as backupmediafamily
    on backupmediafamily.media_set_id = backupset.media_set_id
where backupset.database_name = N'GymManager'
order by backupset.backup_finish_date desc;
go

-- PARTE 6. VERIFICAR UN RESPALDO COMPLETO
use master;
go
restore verifyonly
from disk = N'/backup/GymManager/Full/GymManager_FULL_20261115_000809.bak'
with checksum;
go

-- PARTE 7. COMPROBAR LA RESTAURACIÓN AUXILIAR
select name as BaseDatos, state_desc as Estado, recovery_model_desc as Modelo
from sys.databases
where name in (N'GymManager', N'GymManager_CadenaTest', N'GymManager_PruebaRTO');
go

-- Comparamos el número de registros de las diez tablas.
use master;
go
select 'Socio' as Tabla, (select count(*) from GymManager.Personas.Socio) as Original, (select count(*) from GymManager_CadenaTest.Personas.Socio) as Restaurada
union all
select 'Entrenador' as Tabla, (select count(*) from GymManager.Personas.Entrenador) as Original, (select count(*) from GymManager_CadenaTest.Personas.Entrenador) as Restaurada
union all
select 'TipoMembresia' as Tabla, (select count(*) from GymManager.Membresias.TipoMembresia) as Original, (select count(*) from GymManager_CadenaTest.Membresias.TipoMembresia) as Restaurada
union all
select 'Membresia' as Tabla, (select count(*) from GymManager.Membresias.Membresia) as Original, (select count(*) from GymManager_CadenaTest.Membresias.Membresia) as Restaurada
union all
select 'Pago' as Tabla, (select count(*) from GymManager.Membresias.Pago) as Original, (select count(*) from GymManager_CadenaTest.Membresias.Pago) as Restaurada
union all
select 'TipoClase' as Tabla, (select count(*) from GymManager.Clases.TipoClase) as Original, (select count(*) from GymManager_CadenaTest.Clases.TipoClase) as Restaurada
union all
select 'Especialidad' as Tabla, (select count(*) from GymManager.Clases.Especialidad) as Original, (select count(*) from GymManager_CadenaTest.Clases.Especialidad) as Restaurada
union all
select 'EntrenadorEspecialidad' as Tabla, (select count(*) from GymManager.Clases.EntrenadorEspecialidad) as Original, (select count(*) from GymManager_CadenaTest.Clases.EntrenadorEspecialidad) as Restaurada
union all
select 'SesionClase' as Tabla, (select count(*) from GymManager.Clases.SesionClase) as Original, (select count(*) from GymManager_CadenaTest.Clases.SesionClase) as Restaurada
union all
select 'Reserva' as Tabla, (select count(*) from GymManager.Clases.Reserva) as Original, (select count(*) from GymManager_CadenaTest.Clases.Reserva) as Restaurada;
go

-- PARTE 8. MEDIR UNA RESTAURACIÓN CONTROLADA (OPCIONAL)
if db_id(N'GymManager_PruebaRTO') is null
begin
    declare @Inicio datetime2(3) = sysdatetime();
    declare @Fin datetime2(3);
    restore database GymManager_PruebaRTO
    from disk = N'/backup/GymManager/Full/GymManager_FULL_20261115_000809.bak'
    with move N'GymManager' to N'/var/opt/mssql/data/GymManager_PruebaRTO.mdf',
         move N'GymManager_log' to N'/var/opt/mssql/data/GymManager_PruebaRTO_log.ldf',
         recovery, checksum, stats = 10;
    set @Fin = sysdatetime();
    select @Inicio as HoraInicio, @Fin as HoraFin,
           datediff_big(millisecond, @Inicio, @Fin) as DuracionMilisegundos,
           cast(datediff_big(millisecond, @Inicio, @Fin) / 1000.0 as decimal(12,3)) as DuracionSegundos,
           state_desc as Estado
    from sys.databases where name = N'GymManager_PruebaRTO';
end
else
    print N'GymManager_PruebaRTO ya existe; no se ha sobrescrito.';
go

-- Medición observada en la prueba: 917 ms (0.917 s), estado ONLINE.
-- Solo mide RESTORE DATABASE de un FULL, no el RTO integral del servicio.
-- Retención de 4 semanas (FULL) y 7 días (DIFF/LOG): propuesta,
-- no hay limpieza automática habilitada.
