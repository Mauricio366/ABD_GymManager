--consultas para revisar la base y hacer las pruebas finales.

use GymManager;
go


-- PARTE 1. ESQUEMAS, TABLAS Y RESTRICCIONES
-- Estado de la base principal
select
    name as BaseDatos,
    state_desc as Estado,
    recovery_model_desc as ModeloRecuperacion
from sys.databases
where name = 'GymManager';
go

-- revisar los esquemas
select
    name as Esquema,
    user_name(principal_id) as Propietario
from sys.schemas
where name in ('Personas', 'Membresias', 'Clases', 'BI')
order by name;
go

-- revisar las tablas
select
    s.name as Esquema,
    t.name as Tabla
from sys.tables as t
inner join sys.schemas as s on s.schema_id = t.schema_id
where s.name in ('Personas', 'Membresias', 'Clases')
order by s.name, t.name;
go

-- revisar reglas de las tablas: PK, FK, UNIQUE, CHECK y DEFAULT
select
    s.name as Esquema,
    t.name as Tabla,
    kc.name as Restriccion,
    kc.type_desc as Tipo
from sys.key_constraints as kc
inner join sys.tables as t on t.object_id = kc.parent_object_id
inner join sys.schemas as s on s.schema_id = t.schema_id
order by s.name, t.name, kc.name;
go

select
    s.name as Esquema,
    t.name as Tabla,
    cc.name as Restriccion,
    cc.definition as Regla
from sys.check_constraints as cc
inner join sys.tables as t on t.object_id = cc.parent_object_id
inner join sys.schemas as s on s.schema_id = t.schema_id
order by s.name, t.name, cc.name;
go

select
    s.name as Esquema,
    t.name as Tabla,
    dc.name as Restriccion,
    c.name as Columna,
    dc.definition as ValorPredeterminado
from sys.default_constraints as dc
inner join sys.tables as t on t.object_id = dc.parent_object_id
inner join sys.schemas as s on s.schema_id = t.schema_id
inner join sys.columns as c
    on c.object_id = dc.parent_object_id
   and c.column_id = dc.parent_column_id
order by s.name, t.name, c.name;
go

select
    OBJECT_SCHEMA_NAME(fk.parent_object_id) as Esquema,
    object_name(fk.parent_object_id) as Tabla,
    fk.name as ClaveForanea,
    OBJECT_SCHEMA_NAME(fk.referenced_object_id) as EsquemaReferenciado,
    object_name(fk.referenced_object_id) as TablaReferenciada,
    fk.is_disabled as EstaDeshabilitada
from sys.foreign_keys as fk
order by Esquema, Tabla, ClaveForanea;
go


-- PARTE 2. ÍNDICES Y ESTRUCTURA DE ACCESO
select
    schema_name(o.schema_id) as Esquema,
    o.name as Tabla,
    i.name as Indice,
    i.type_desc as Tipo,
    i.is_unique as EsUnico,
    i.has_filter as TieneFiltro,
    i.filter_definition as Filtro
from sys.indexes as i
inner join sys.objects as o on o.object_id = i.object_id
where o.type = 'U'
  and i.index_id > 0
order by Esquema, Tabla, Indice;
go


-- PARTE 3. VISTAS BI Y CONSULTAS AVANZADAS
-- Procedimientos almacenados y vistas BI
select
    schema_name(schema_id) as Esquema,
    name as Procedimiento
from sys.procedures
where name in (
    'sp_RegistrarPago',
    'sp_RegistrarReserva',
    'sp_CancelarReserva',
    'sp_RegistrarAsistencia',
    'sp_ActualizarMembresiasVencidas'
)
order by Esquema, Procedimiento;
go

select
    schema_name(schema_id) as Esquema,
    name as Vista
from sys.views
where name in (
    'vw_MembresiasProximas',
    'vw_IngresosMensuales',
    'vw_PopularidadClases',
    'vw_MembresiasActivas',
    'vw_TotalSocios',
    'vw_TotalReservas'
)
order by Esquema, Vista;
go

-- CONTEOS DE DATOS
-- Socios 250, Membresías 400, Pagos 400, Reservas 2500.
select 'Socios' as Tabla, count_big(*) as Total from Personas.Socio
union all select 'Entrenadores', count_big(*) from Personas.Entrenador
union all select 'TiposMembresia', count_big(*) from Membresias.TipoMembresia
union all select 'Membresias', count_big(*) from Membresias.Membresia
union all select 'Pagos', count_big(*) from Membresias.Pago
union all select 'TiposClase', count_big(*) from Clases.TipoClase
union all select 'Sesiones', count_big(*) from Clases.SesionClase
union all select 'Reservas', count_big(*) from Clases.Reserva
union all select 'Especialidades', count_big(*) from Clases.Especialidad
union all select 'EntrenadorEspecialidad', count_big(*) from Clases.EntrenadorEspecialidad;
go

-- 8. CONSULTA DE LAS SEIS VISTAS BI
--Tres vistas analíticas principales y tres vistas de indicadores del dashboard.

select *
from BI.vw_MembresiasProximas
order by FechaVencimiento, IdMembresia;
go

select *
from BI.vw_IngresosMensuales
order by InicioMes;
go

select *
from BI.vw_PopularidadClases
order by RankingPopularidad, TipoClase;
go

select *
from BI.vw_MembresiasActivas;
go

select *
from BI.vw_TotalSocios;
go

select *
from BI.vw_TotalReservas;
go


-- PARTE 4. FUNCIONES DE VENTANA (ROW_NUMBER, COUNT OVER, LAG, RANK, SUM OVER)
-- Estas consultas leen las vistas que implementan las funciones de ventana.
select NumeroOrden, IdMembresia, FechaVencimiento, TotalProximasVencer
from BI.vw_MembresiasProximas
order by NumeroOrden;
go

select InicioMes, Ingresos, IngresosMesAnterior, DiferenciaMensual, PorcentajeVariacion
from BI.vw_IngresosMensuales
order by InicioMes;
go

select TipoClase, TotalReservas, RankingPopularidad, PorcentajeReservas
from BI.vw_PopularidadClases
order by RankingPopularidad, TipoClase;
go

-- ASIGNACIÓN DE LOS CINCO USUARIOS A LOS CUATRO ROLES
select
    R.name as Rol,
    U.name as Usuario
from sys.database_role_members as RM
inner join sys.database_principals as R
    on RM.role_principal_id = R.principal_id
inner join sys.database_principals as U
    on RM.member_principal_id = U.principal_id
where R.name in (
    'Gym_Admin', 'Gym_Recepcion', 'Gym_Entrenador', 'Gym_AnalistaBI'
)
order by R.name, U.name;
go


-- PERMISOS EXPLÍCITOS DE LOS CUATRO ROLES
select
    user_name(P.grantee_principal_id) as Rol,
    P.permission_name as Permiso,
    P.state_desc as Estado,
    case
        when P.class = 0 then 'Base de datos'
        when P.class = 3 then schema_name(P.major_id)
        when P.class = 1 then
            OBJECT_SCHEMA_NAME(P.major_id) + '.' + object_name(P.major_id)
        else 'Otro'
    end as Objeto
from sys.database_permissions as P
where P.grantee_principal_id in (
    select principal_id
    from sys.database_principals
    where name in (
        'Gym_Admin', 'Gym_Recepcion', 'Gym_Entrenador', 'Gym_AnalistaBI'
    )
)
order by Rol, Objeto, Permiso;
go


-- PARTE 5. SEGURIDAD, ROLES Y PRIVILEGIOS

-- El analista BI sí puede consultar las vistas del dashboard.
execute as user = 'Usuario_AnalistaBI';
select user_name() as UsuarioActual;
select top (5) * from BI.vw_IngresosMensuales;
revert;
go

-- El analista BI no debe poder leer los datos personales (se espera el error 229).
execute as user = 'Usuario_AnalistaBI';
begin try
    select top (5) * from Personas.Socio;
    print 'ERROR: el acceso a Personas.Socio fue permitido.';
end try
begin catch
    print 'Correcto: acceso denegado a Personas.Socio.';
    print error_message();
end catch;
revert;
go

-- El entrenador sí puede consultar las sesiones.
execute as user = 'Usuario_Entrenador';
select user_name() as UsuarioActual;
select top (5) * from Clases.SesionClase;
revert;
go

-- El entrenador no debe poder consultar los pagos (se espera el error 229).
execute as user = 'Usuario_Entrenador';
begin try
    select top (5) * from Membresias.Pago;
    print 'ERROR: el acceso a Membresias.Pago fue permitido.';
end try
begin catch
    print 'Correcto: acceso denegado a Membresias.Pago.';
    print error_message();
end catch;
revert;
go

-- Recepción puede consultar socios y pagos.
execute as user = 'Usuario_Recepcion';
select user_name() as UsuarioActual;
select top (5) * from Personas.Socio;
select top (5) * from Membresias.Pago;
revert;
go

-- Recepción no puede modificar directamente los pagos 
execute as user = 'Usuario_Recepcion';
begin try
    update Membresias.Pago
    set Monto = Monto
    where 1 = 0;
    print 'ERROR: se permitió UPDATE directo sobre Pago.';
end try
begin catch
    print 'Correcto: UPDATE directo sobre Pago denegado.';
    print error_message();
end catch;
revert;
go

-- El administrador puede consultar los cuatro esquemas.
execute as user = 'Usuario_Admin';
select user_name() as UsuarioActual;
select top (3) * from Personas.Socio;
select top (3) * from Membresias.Pago;
select top (3) * from Clases.SesionClase;
select top (3) * from BI.vw_IngresosMensuales;
revert;
go

-- Power BI: usuario real asociado al login LoginPowerBI.
-- Las consultas de las seis vistas BI deben funcionar; el acceso a datos personales debe fallar.
execute as user = 'Usuario_PowerBI';
select user_name() as UsuarioActual;
select top (5) * from BI.vw_IngresosMensuales;
select top (5) * from BI.vw_MembresiasProximas;
select top (5) * from BI.vw_PopularidadClases;
select * from BI.vw_MembresiasActivas;
select * from BI.vw_TotalSocios;
select * from BI.vw_TotalReservas;
begin try
    select top (1) * from Personas.Socio;
    print 'ERROR: Usuario_PowerBI pudo acceder a Personas.Socio.';
end try
begin catch
    print 'Correcto: acceso de Usuario_PowerBI a Personas.Socio denegado.';
    print ERROR_MESSAGE();
end catch;
revert;
go

-- Recepción: puede ejecutar los procedimientos asignados.
execute as user = 'Usuario_Recepcion';
select has_perms_by_name('Membresias.sp_RegistrarPago', 'OBJECT', 'EXECUTE')
    as PuedeRegistrarPago,
       has_perms_by_name('Clases.sp_RegistrarReserva', 'OBJECT', 'EXECUTE')
    as PuedeRegistrarReserva,
       has_perms_by_name('Clases.sp_CancelarReserva', 'OBJECT', 'EXECUTE')
    as PuedeCancelarReserva;
revert;
go

-- Entrenador: puede ejecutar el procedimiento de asistencia.
execute as user = 'Usuario_Entrenador';
select has_perms_by_name('Clases.sp_RegistrarAsistencia', 'OBJECT', 'EXECUTE')
    as PuedeRegistrarAsistencia;
revert;
go

-- Administrador: control sobre los cuatro esquemas.
execute as user = 'Usuario_Admin';
select
    has_perms_by_name('Personas', 'SCHEMA', 'CONTROL') as ControlPersonas,
    has_perms_by_name('Membresias', 'SCHEMA', 'CONTROL') as ControlMembresias,
    has_perms_by_name('Clases', 'SCHEMA', 'CONTROL') as ControlClases,
    has_perms_by_name('BI', 'SCHEMA', 'CONTROL') as ControlBI;
revert;
go

-- PARTE 6. PROCEDIMIENTOS ALMACENADOS Y PRUEBAS FUNCIONALES

-- sp_RegistrarPago: rechazo de segundo pago para membresía ya pagada.

begin try
    exec Membresias.sp_RegistrarPago
        @IdMembresia = 259,
        @Monto = 220.00,
        @MetodoPago = N'Tarjeta',
        @Referencia = N'PRUEBA-DUPLICADO-20261113';
    print 'ERROR: se aceptó un segundo pago.';
end try
begin catch
    print 'Resultado esperado: segundo pago rechazado.';
    print error_message();
end catch;
go

-- sp_RegistrarReserva: reserva exitosa temporal.

begin try
    begin transaction;

    exec Clases.sp_RegistrarReserva
        @IdSocio = 9,
        @IdSesion = 359;

    rollback transaction;
    print 'Correcto: reserva temporal revertida.';
end try
begin catch
    if @@TRANCOUNT > 0 rollback transaction;
    print 'Error en la prueba de reserva:';
    print error_message();
end catch;
go

-- sp_RegistrarReserva: rechazo de reserva duplicada.

begin try
    exec Clases.sp_RegistrarReserva
        @IdSocio = 102,
        @IdSesion = 352;
    print 'ERROR: se aceptó una reserva duplicada.';
end try
begin catch
    print 'Resultado esperado: reserva duplicada rechazada.';
    print error_message();
end catch;
go

-- sp_CancelarReserva: cancelación exitosa temporal.

begin try
    begin transaction;

    exec Clases.sp_CancelarReserva @IdReserva = 1;

    rollback transaction;
    print 'Correcto: cancelación temporal revertida.';
end try
begin catch
    if @@TRANCOUNT > 0 rollback transaction;
    print 'Error en la prueba de cancelación:';
    print error_message();
end catch;
go

-- sp_RegistrarAsistencia: asistencia exitosa temporal.

begin try
    begin transaction;

    exec Clases.sp_RegistrarReserva
        @IdSocio = 9,
        @IdSesion = 359;

    declare @IdReservaAsistencia int;
    select @IdReservaAsistencia = max(IdReserva)
    from Clases.Reserva
    where IdSocio = 9
      and IdSesion = 359;

    update Clases.SesionClase
    set Estado = 'Finalizada'
    where IdSesion = 359;

    exec Clases.sp_RegistrarAsistencia
        @IdReserva = @IdReservaAsistencia,
        @Asistio = 1;

    rollback transaction;
    print 'Correcto: asistencia temporal revertida.';
end try
begin catch
    if @@TRANCOUNT > 0 rollback transaction;
    print 'Error en la prueba de asistencia:';
    print error_message();
end catch;
go

-- sp_ActualizarMembresiasVencidas: actualización temporal.

begin try
    begin transaction;

    exec Membresias.sp_ActualizarMembresiasVencidas;

    rollback transaction;
    print 'Correcto: actualización temporal revertida.';
end try
begin catch
    if @@TRANCOUNT > 0 rollback transaction;
    print 'Error en la prueba de actualización de membresías:';
    print error_message();
end catch;
go


-- VERIFICACIÓN DE LOS ÍNDICES UTILIZADOS POR LAS VISTAS
-- Confirma la existencia, habilitación y filtro del índice de vencimientos.
select
    i.name as Indice,
    i.type_desc as Tipo,
    i.is_disabled as Deshabilitado,
    i.has_filter as TieneFiltro,
    i.filter_definition as Filtro
from sys.indexes as i
where i.object_id = object_id(N'Membresias.Membresia')
  and i.name = N'IX_Membresia_Vencimiento_Activa';
go

-- También se puede comprobar el índice de ingresos:
select
    i.name as Indice,
    i.type_desc as Tipo,
    i.is_disabled as Deshabilitado
from sys.indexes as i
where i.object_id = object_id(N'Membresias.Pago')
  and i.name = N'IX_Pago_Fecha_Estado';
go

-- PARTE 7. OPTIMIZACIÓN: ESTADÍSTICAS IO/TIME Y PLAN REAL
-- Activar STATISTICS IO/TIME y revisar también el plan de ejecución real
-- desde SSMS (Ctrl+M). Los tiempos pueden variar entre ejecuciones.
set statistics io on;
set statistics time on;
go

select * from BI.vw_MembresiasProximas;
go
select * from BI.vw_IngresosMensuales;
go
select * from BI.vw_PopularidadClases;
go

set statistics io off;
set statistics time off;
go


-- PARTE 8. AUDITORÍA: ESTADO Y EVENTOS
use master;
go

select
    name as Auditoria,
    is_state_enabled as EstaActiva,
    type_desc as TipoDestino
from sys.server_audits
where name = N'GymManager_Audit';
go

use GymManager;
go

select
    name as Especificacion,
    is_state_enabled as EstaActiva,
    audit_guid as IdentificadorAuditoria
from sys.database_audit_specifications
where name = N'GymManager_DB_Audit';
go

-- Consultar los eventos guardados en los archivos de auditoría.
select
    event_time,
    action_id,
    succeeded,
    server_principal_name,
    database_principal_name,
    database_name,
    schema_name,
    object_name,
    statement
from sys.fn_get_audit_file(
    '/var/opt/mssql/log/GymManager_Audit*.sqlaudit',
    default,
    default
)
where database_name = N'GymManager'
order by event_time desc;
go

-- Códigos relevantes observados:
-- SL = SELECT; UP = UPDATE; Succeeded = 1 indica operación exitosa.

-- Para probar un permiso denegado, ejecutar este bloque por separado.
use GymManager;
go
begin try
    execute as user = 'Usuario_Recepcion';
    update Membresias.Pago set Monto = Monto where 1 = 0;
    revert;
end try
begin catch
    if user_name() = N'Usuario_Recepcion' revert;
    select error_number() as CodigoError, error_message() as MensajeError;
end catch;
go
