-- GymManager: aquí está el script para crear la base, cargar los datos


-- 1. Base de datos y esquemas

if db_id('GymManager') is null
begin
    create database GymManager;
end;
go

use GymManager;
go


-- Este esquema guarda los datos de socios y entrenadores.
if schema_id('Personas') is null
begin
    exec('create schema Personas authorization dbo');
end;
go

-- Aquí van los planes, membresías y pagos.
if schema_id('Membresias') is null
begin
    exec('create schema Membresias authorization dbo');
end;
go

-- Aquí se guardan las clases, sesiones y reservas.
if schema_id('Clases') is null
begin
    exec('create schema Clases authorization dbo');
end;
go

-- Esquema de vistas de inteligencia de negocios.
if schema_id('BI') is null
begin
    exec('create schema BI authorization dbo');
end;
go

-- 2. Tablas y relaciones

-- 1. TABLA: Personas.Socio

create table Personas.Socio (
    IdSocio int identity(1,1) not null,
    Nombres nvarchar(60) not null,
    Apellidos nvarchar(60) not null,
    DUI nvarchar(20) not null,
    FechaNacimiento date not null,
    Telefono nvarchar(20) null,
    Correo nvarchar(100) null,
    FechaRegistro date not null
        constraint DF_Socio_FechaRegistro default (convert(date, getdate())),
    Estado nvarchar(15) not null
        constraint DF_Socio_Estado default ('Activo'),

    constraint PK_Socio primary key (IdSocio),
    constraint UQ_Socio_DUI unique (DUI),

    constraint CK_Socio_Estado
        check (Estado in ('Activo', 'Inactivo'))
);
go

-- 2. TABLA: Personas.Entrenador

create table Personas.Entrenador (
    IdEntrenador int identity(1,1) not null,
    Nombres nvarchar(60) not null,
    Apellidos nvarchar(60) not null,
    DUI nvarchar(20) not null,
    Telefono nvarchar(20) null,
    Correo nvarchar(100) null,
    FechaContratacion date not null
        constraint DF_Entrenador_FechaContratacion
        default (convert(date, getdate())),
    Estado nvarchar(15) not null
        constraint DF_Entrenador_Estado default ('Activo'),

    constraint PK_Entrenador primary key (IdEntrenador),
    constraint UQ_Entrenador_DUI unique (DUI),

    constraint CK_Entrenador_Estado
        check (Estado in ('Activo', 'Inactivo'))
);
go

-- 3. TABLA: Membresias.TipoMembresia

create table Membresias.TipoMembresia (
    IdTipoMembresia int identity(1,1) not null,
    Nombre nvarchar(40) not null,
    DuracionMeses tinyint not null,
    Precio decimal(10,2) not null,
    Descripcion nvarchar(200) null,
    Estado nvarchar(15) not null
        constraint DF_TipoMembresia_Estado default ('Activo'),

    constraint PK_TipoMembresia primary key (IdTipoMembresia),
    constraint UQ_TipoMembresia_Nombre unique (Nombre),

    constraint CK_TipoMembresia_Duracion
        check (DuracionMeses > 0),

    constraint CK_TipoMembresia_Precio
        check (Precio > 0),

    constraint CK_TipoMembresia_Estado
        check (Estado in ('Activo', 'Inactivo'))
);
go

-- 4. TABLA: Clases.TipoClase

create table Clases.TipoClase (
    IdTipoClase int identity(1,1) not null,
    Nombre nvarchar(50) not null,
    Descripcion nvarchar(200) null,
    DuracionMinutos smallint not null,
    Estado nvarchar(15) not null
        constraint DF_TipoClase_Estado default ('Activo'),

    constraint PK_TipoClase primary key (IdTipoClase),
    constraint UQ_TipoClase_Nombre unique (Nombre),

    constraint CK_TipoClase_Duracion
        check (DuracionMinutos > 0),

    constraint CK_TipoClase_Estado
        check (Estado in ('Activo', 'Inactivo'))
);
go

-- 5. TABLA: Clases.Especialidad

create table Clases.Especialidad (
    IdEspecialidad int identity(1,1) not null,
    Nombre nvarchar(60) not null,
    Descripcion nvarchar(200) null,

    constraint PK_Especialidad primary key (IdEspecialidad),
    constraint UQ_Especialidad_Nombre unique (Nombre)
);
go

-- 6. TABLA: Membresias.Membresia

create table Membresias.Membresia (
    IdMembresia int identity(1,1) not null,
    IdSocio int not null,
    IdTipoMembresia int not null,
    FechaInicio date null,
    FechaVencimiento date null,
    PrecioContratado decimal(10,2) not null,
    Estado nvarchar(15) not null
        constraint DF_Membresia_Estado default ('PendientePago'),

    constraint PK_Membresia primary key (IdMembresia),

    constraint FK_Membresia_Socio
        foreign key (IdSocio)
        references Personas.Socio(IdSocio),

    constraint FK_Membresia_TipoMembresia
        foreign key (IdTipoMembresia)
        references Membresias.TipoMembresia(IdTipoMembresia),

    constraint CK_Membresia_Precio
        check (PrecioContratado > 0),

    constraint CK_Membresia_Estado
        check (Estado in (
            'PendientePago',
            'Activa',
            'Suspendida',
            'Cancelada',
            'Vencida'
        )),

    constraint CK_Membresia_Fechas
        check (
            (Estado = 'PendientePago'
                and FechaInicio is null
                and FechaVencimiento is null)
            or
            (Estado <> 'PendientePago'
                and FechaInicio is not null
                and FechaVencimiento is not null
                and FechaVencimiento > FechaInicio)
        )
);
go

-- 7. TABLA: Membresias.Pago

create table Membresias.Pago (
    IdPago int identity(1,1) not null,
    IdMembresia int not null,
    FechaHoraPago datetime2(0) not null
        constraint DF_Pago_FechaHora default (sysdatetime()),
    Monto decimal(10,2) not null,
    MetodoPago nvarchar(30) not null,
    Estado nvarchar(15) not null
        constraint DF_Pago_Estado default ('Pagado'),
    Referencia nvarchar(50) null,

    constraint PK_Pago primary key (IdPago),

    constraint FK_Pago_Membresia
        foreign key (IdMembresia)
        references Membresias.Membresia(IdMembresia),

    constraint CK_Pago_Monto
        check (Monto > 0),

    constraint CK_Pago_Estado
        check (Estado in ('Pagado', 'Anulado'))
);
go

-- 8. TABLA: Clases.SesionClase

create table Clases.SesionClase (
    IdSesion int identity(1,1) not null,
    IdTipoClase int not null,
    IdEntrenador int not null,
    Fecha date not null,
    HoraInicio time(0) not null,
    HoraFin time(0) not null,
    CapacidadMaxima smallint not null,
    Estado nvarchar(15) not null
        constraint DF_SesionClase_Estado default ('Programada'),

    constraint PK_SesionClase primary key (IdSesion),

    constraint FK_SesionClase_TipoClase
        foreign key (IdTipoClase)
        references Clases.TipoClase(IdTipoClase),

    constraint FK_SesionClase_Entrenador
        foreign key (IdEntrenador)
        references Personas.Entrenador(IdEntrenador),

    constraint CK_SesionClase_Horario
        check (HoraFin > HoraInicio),

    constraint CK_SesionClase_Capacidad
        check (CapacidadMaxima > 0),

    constraint CK_SesionClase_Estado
        check (Estado in (
            'Programada',
            'Cancelada',
            'Finalizada'
        ))
);
go

-- 9. TABLA: Clases.Reserva

create table Clases.Reserva (
    IdReserva int identity(1,1) not null,
    IdSocio int not null,
    IdSesion int not null,
    FechaReserva datetime2(0) not null
        constraint DF_Reserva_Fecha default (sysdatetime()),
    Estado nvarchar(15) not null
        constraint DF_Reserva_Estado default ('Reservada'),
    FechaAsistencia datetime2(0) null,

    constraint PK_Reserva primary key (IdReserva),

    constraint FK_Reserva_Socio
        foreign key (IdSocio)
        references Personas.Socio(IdSocio),

    constraint FK_Reserva_SesionClase
        foreign key (IdSesion)
        references Clases.SesionClase(IdSesion),

    constraint CK_Reserva_Estado
        check (Estado in (
            'Reservada',
            'Cancelada',
            'Asistió',
            'No asistió'
        )),

    constraint CK_Reserva_FechaAsistencia
        check (
            (Estado = 'Asistió' and FechaAsistencia is not null)
            or
            (Estado <> 'Asistió' and FechaAsistencia is null)
        )
);
go

-- 10. TABLA: Clases.EntrenadorEspecialidad

create table Clases.EntrenadorEspecialidad (
    IdEntrenador int not null,
    IdEspecialidad int not null,

    constraint PK_EntrenadorEspecialidad
        primary key (IdEntrenador, IdEspecialidad),

    constraint FK_EntrenadorEspecialidad_Entrenador
        foreign key (IdEntrenador)
        references Personas.Entrenador(IdEntrenador),

    constraint FK_EntrenadorEspecialidad_Especialidad
        foreign key (IdEspecialidad)
        references Clases.Especialidad(IdEspecialidad)
);
go

-- 3. Índices para las consultas y reglas del sistema
-- Índices para búsquedas frecuentes y reglas de unicidad.
use GymManager;
go

-- 1. CORREOS ÚNICOS DE LOS SOCIOS

create unique index UX_Socio_Correo
on Personas.Socio (Correo)
where Correo is not null
  and Correo <> N'';
go

-- 2. CORREOS ÚNICOS DE LOS ENTRENADORES

create unique index UX_Entrenador_Correo
on Personas.Entrenador (Correo)
where Correo is not null
  and Correo <> N'';
go

-- 3. UNA MEMBRESÍA ACTIVA POR SOCIO

create unique index UX_Membresia_Socio_Activa
on Membresias.Membresia (IdSocio)
where Estado = 'Activa';
go

-- 4. EVITAR RESERVAS DUPLICADAS VIGENTES

create unique index UX_Reserva_Socio_Sesion
on Clases.Reserva (IdSocio, IdSesion)
where Estado <> 'Cancelada';
go

-- 5. UN SOLO PAGO VÁLIDO POR MEMBRESÍA

create unique index UX_Pago_Membresia_Pagado
on Membresias.Pago (IdMembresia)
where Estado = 'Pagado';
go

-- 6. CONSULTA DE MEMBRESÍAS POR SOCIO

create index IX_Membresia_Socio_Estado
on Membresias.Membresia (IdSocio, Estado)
include (FechaInicio, FechaVencimiento, PrecioContratado);
go

-- Índice filtrado para la consulta BI de membresías próximas a vencer.
-- Se probó con el plan de ejecución real y SQL Server utilizó Index Seek.
create nonclustered index IX_Membresia_Vencimiento_Activa
on Membresias.Membresia
(
    FechaVencimiento,
    IdMembresia
)
include
(
    IdSocio,
    IdTipoMembresia,
    FechaInicio
)
where Estado = 'Activa';
go

-- 7. CONSULTA DE PAGOS POR MEMBRESÍA

create index IX_Pago_Membresia_Estado
on Membresias.Pago (IdMembresia, Estado)
include (Monto, FechaHoraPago);
go

-- 8. CONSULTA DE RESERVAS POR SESIÓN

create index IX_Reserva_Sesion_Estado
on Clases.Reserva (IdSesion, Estado)
include (IdSocio);
go

-- 9. CONSULTA DE SESIONES POR FECHA

create index IX_SesionClase_Fecha_Estado
on Clases.SesionClase (Fecha, Estado)
include (
    IdTipoClase,
    IdEntrenador,
    HoraInicio,
    HoraFin,
    CapacidadMaxima
);
go

-- Este índice se dejó porque ayudó a la consulta de ingresos mensuales.
create nonclustered index IX_Pago_Fecha_Estado
on Membresias.Pago (FechaHoraPago, Estado)
include (Monto);
go

-- 4. Procedimientos que usa el sistema
--Este procedimiento registra el pago completo de una membresía.

use GymManager;
go

create or alter procedure Membresias.sp_RegistrarPago
    @IdMembresia int,
    @Monto decimal(10,2),
    @MetodoPago nvarchar(30),
    @Referencia nvarchar(50) = null
as
begin
    set nocount on;
    set xact_abort on;

    declare @PrecioContratado decimal(10,2);
    declare @DuracionMeses tinyint;
    declare @FechaInicio date;
    declare @FechaVencimiento date;
    declare @Estado nvarchar(15);

    begin try
        begin transaction;

        -- 1. Validar el monto
        if @Monto is null or @Monto <= 0
            throw 50001, 'El monto debe ser mayor que cero.', 1;

        -- 2. Validar el método de pago
        if @MetodoPago is null
           or LTRIM(RTRIM(@MetodoPago)) not in (
                'Efectivo',
                'Tarjeta',
                'Transferencia'
           )
            throw 50002, 'El método de pago no es válido.', 1;

        -- 3. Consultar y bloquear la membresía
        select
            @PrecioContratado = M.PrecioContratado,
            @DuracionMeses = T.DuracionMeses,
            @Estado = M.Estado
        from Membresias.Membresia as M with (updlock, holdlock)
        inner join Membresias.TipoMembresia as T
            on M.IdTipoMembresia = T.IdTipoMembresia
        where M.IdMembresia = @IdMembresia;

        -- 4. Verificar existencia
        if @PrecioContratado is null
            throw 50003, 'La membresía no existe.', 1;

        -- 5. Verificar estado
        if @Estado <> 'PendientePago'
            throw 50004, 'La membresía no está pendiente de pago.', 1;

        -- 6. Verificar pago completo
        if @Monto <> @PrecioContratado
            throw 50005, 'El monto debe coincidir con el precio completo de la membresía.', 1;

        -- 7. Establecer fechas de vigencia
        set @FechaInicio = convert(date, getdate());

        set @FechaVencimiento =
            dateadd(month, @DuracionMeses, @FechaInicio);

        -- 8. Registrar el pago completo
        insert into Membresias.Pago (
            IdMembresia,
            FechaHoraPago,
            Monto,
            MetodoPago,
            Estado,
            Referencia
        )
        values (
            @IdMembresia,
            sysdatetime(),
            @Monto,
            LTRIM(RTRIM(@MetodoPago)),
            'Pagado',
            @Referencia
        );

        -- 9. Activar la membresía
        update Membresias.Membresia
        set
            FechaInicio = @FechaInicio,
            FechaVencimiento = @FechaVencimiento,
            Estado = 'Activa'
        where IdMembresia = @IdMembresia;

        commit transaction;

        -- 10. Devolver el resultado
        select
            M.IdMembresia,
            M.IdSocio,
            P.IdPago,
            P.Monto,
            P.MetodoPago,
            M.FechaInicio,
            M.FechaVencimiento,
            M.Estado as EstadoMembresia,
            P.Estado as EstadoPago
        from Membresias.Membresia M
        inner join Membresias.Pago P
            on M.IdMembresia = P.IdMembresia
        where M.IdMembresia = @IdMembresia
          and P.Estado = 'Pagado';

    end try
    begin catch

        if @@TRANCOUNT > 0
            rollback transaction;

        throw;

    end catch;
end;
go

--Esto sirve para reservar un lugar en una sesión.

use GymManager;
go

create or alter procedure Clases.sp_RegistrarReserva
    @IdSocio int,
    @IdSesion int
as
begin
    set nocount on;
    set xact_abort on;

    declare @EstadoSocio nvarchar(15);
    declare @EstadoSesion nvarchar(15);
    declare @FechaSesion date;
    declare @CapacidadMaxima smallint;
    declare @ReservasActuales int;
    declare @TieneMembresiaValida bit = 0;

    begin try
        begin transaction;

        -- 1. Bloquear y consultar la sesión
        select
            @EstadoSesion = Estado,
            @FechaSesion = Fecha,
            @CapacidadMaxima = CapacidadMaxima
        from Clases.SesionClase with (updlock, holdlock)
        where IdSesion = @IdSesion;

        if @CapacidadMaxima is null
            throw 50010, 'La sesión no existe.', 1;

        if @EstadoSesion <> 'Programada'
            throw 50011, 'La sesión no está disponible para reservas.', 1;

        -- 2. Verificar que el socio exista y esté activo
        select @EstadoSocio = Estado
        from Personas.Socio
        where IdSocio = @IdSocio;

        if @EstadoSocio is null
            throw 50012, 'El socio no existe.', 1;

        if @EstadoSocio <> 'Activo'
            throw 50013, 'El socio está inactivo.', 1;

        -- 3. Verificar membresía pagada y vigente
        if exists (
            select 1
            from Membresias.Membresia M
            inner join Membresias.Pago P
                on M.IdMembresia = P.IdMembresia
            where M.IdSocio = @IdSocio
              and M.Estado = 'Activa'
              and P.Estado = 'Pagado'
              and P.Monto = M.PrecioContratado
              and M.FechaInicio <= @FechaSesion
              and M.FechaVencimiento > @FechaSesion
        )
            set @TieneMembresiaValida = 1;

        if @TieneMembresiaValida = 0
            throw 50014, 'El socio no tiene una membresía pagada y vigente para esta sesión.', 1;

        -- 4. Evitar reservas duplicadas
        if exists (
            select 1
            from Clases.Reserva
            where IdSocio = @IdSocio
              and IdSesion = @IdSesion
              and Estado <> 'Cancelada'
        )
            throw 50015, 'El socio ya tiene una reserva vigente para esta sesión.', 1;

        -- 5. Contar reservas que ocupan cupo
        select @ReservasActuales = count(*)
        from Clases.Reserva with (updlock, holdlock)
        where IdSesion = @IdSesion
          and Estado in ('Reservada', 'Asistió', 'No asistió');

        if @ReservasActuales >= @CapacidadMaxima
            throw 50016, 'La sesión ha alcanzado su capacidad máxima.', 1;

        -- 6. Registrar reserva
        insert into Clases.Reserva (
            IdSocio,
            IdSesion,
            FechaReserva,
            Estado,
            FechaAsistencia
        )
        values (
            @IdSocio,
            @IdSesion,
            sysdatetime(),
            'Reservada',
            null
        );

        commit transaction;

        select
            IdReserva,
            IdSocio,
            IdSesion,
            FechaReserva,
            Estado
        from Clases.Reserva
        where IdReserva = SCOPE_IDENTITY();

    end try
    begin catch

        if @@TRANCOUNT > 0
            rollback transaction;

        throw;

    end catch;
end;
go

--Esto cancela una reserva, pero conserva el registro.

use GymManager;
go

create or alter procedure Clases.sp_CancelarReserva
    @IdReserva int
as
begin
    set nocount on;
    set xact_abort on;

    begin try
        begin transaction;

        declare @EstadoReserva nvarchar(15);

        -- 1. Consultar y bloquear la reserva
        select @EstadoReserva = Estado
        from Clases.Reserva with (updlock, holdlock)
        where IdReserva = @IdReserva;

        -- 2. Verificar existencia
        if @EstadoReserva is null
            throw 50020, 'La reserva no existe.', 1;

        -- 3. Verificar que no esté cancelada
        if @EstadoReserva = 'Cancelada'
            throw 50021, 'La reserva ya está cancelada.', 1;

        -- 4. No permitir cancelar una asistencia registrada
        if @EstadoReserva in ('Asistió', 'No asistió')
            throw 50022, 'No se puede cancelar una reserva que ya fue atendida o registrada como inasistencia.', 1;

        -- 5. Cancelar conservando el historial
        update Clases.Reserva
        set
            Estado = 'Cancelada',
            FechaAsistencia = null
        where IdReserva = @IdReserva;

        commit transaction;

        -- 6. Devolver resultado
        select
            IdReserva,
            IdSocio,
            IdSesion,
            FechaReserva,
            Estado
        from Clases.Reserva
        where IdReserva = @IdReserva;

    end try
    begin catch

        if @@TRANCOUNT > 0
            rollback transaction;

        throw;

    end catch;
end;
go

--Esto registra si la persona asistió o no a la sesión.

use GymManager;
go

create or alter procedure Clases.sp_RegistrarAsistencia
    @IdReserva int,
    @Asistio bit
as
begin
    set nocount on;
    set xact_abort on;

    begin try
        begin transaction;

        declare @EstadoReserva nvarchar(15);
        declare @EstadoSesion nvarchar(15);

        -- 1. Consultar y bloquear la reserva
        select @EstadoReserva = R.Estado
        from Clases.Reserva as R with (updlock, holdlock)
        where R.IdReserva = @IdReserva;

        if @EstadoReserva is null
            throw 50030, 'La reserva no existe.', 1;

        if @EstadoReserva <> 'Reservada'
            throw 50031, 'La reserva no está disponible para registrar asistencia.', 1;

        -- 2. Consultar estado de la sesión
        select @EstadoSesion = S.Estado
        from Clases.Reserva as R
        inner join Clases.SesionClase as S
            on R.IdSesion = S.IdSesion
        where R.IdReserva = @IdReserva;

        if @EstadoSesion <> 'Finalizada'
            throw 50032, 'La sesión debe estar finalizada para registrar la asistencia.', 1;

        -- 3. Actualizar reserva
        update Clases.Reserva
        set
            Estado = case
                when @Asistio = 1 then 'Asistió'
                else 'No asistió'
            end,
            FechaAsistencia = case
                when @Asistio = 1 then sysdatetime()
                else null
            end
        where IdReserva = @IdReserva;

        commit transaction;

        -- 4. Devolver resultado
        select
            IdReserva,
            IdSocio,
            IdSesion,
            Estado,
            FechaAsistencia
        from Clases.Reserva
        where IdReserva = @IdReserva;

    end try
    begin catch

        if @@TRANCOUNT > 0
            rollback transaction;

        throw;

    end catch;
end;
go

--Esto cambia a Vencida las membresías que ya pasaron su fecha.

use GymManager;
go

create or alter procedure Membresias.sp_ActualizarMembresiasVencidas
as
begin
    set nocount on;
    set xact_abort on;

    begin try
        begin transaction;

        update Membresias.Membresia
        set Estado = 'Vencida'
        where Estado = 'Activa'
          and FechaVencimiento <= convert(date, getdate());

        select
            @@rowcount as MembresiasActualizadas;

        commit transaction;

    end try
    begin catch

        if @@TRANCOUNT > 0
            rollback transaction;

        throw;

    end catch;
end;
go

-- 5. Datos de ejemplo para poder probar el sistema
use GymManager;
go


-- 1. PLANES DE MEMBRESÍA

insert into Membresias.TipoMembresia
    (Nombre, DuracionMeses, Precio, Descripcion)
values
    ('Mensual', 1, 25.00, 'Membresía de un mes'),
    ('Trimestral', 3, 65.00, 'Membresía de tres meses'),
    ('Anual', 12, 220.00, 'Membresía de doce meses');
go

-- 2. TIPOS DE CLASE

insert into Clases.TipoClase
    (Nombre, Descripcion, DuracionMinutos)
values
    ('Spinning', 'Entrenamiento cardiovascular en bicicleta', 45),
    ('Yoga', 'Ejercicios de flexibilidad y relajación', 60),
    ('CrossFit', 'Entrenamiento funcional de alta intensidad', 60),
    ('Zumba', 'Actividad física mediante baile', 50),
    ('Pilates', 'Entrenamiento de fuerza y estabilidad', 50),
    ('Musculación', 'Entrenamiento con pesas y máquinas', 60);
go

-- 3. ESPECIALIDADES

insert into Clases.Especialidad
    (Nombre, Descripcion)
values
    ('Entrenamiento funcional', 'Especialización en ejercicios funcionales'),
    ('Cardio', 'Especialización en entrenamiento cardiovascular'),
    ('Yoga', 'Especialización en prácticas de yoga'),
    ('Musculación', 'Especialización en entrenamiento de fuerza'),
    ('Pilates', 'Especialización en pilates'),
    ('Baile fitness', 'Especialización en actividades de baile'),
    ('Acondicionamiento físico', 'Preparación física general'),
    ('Flexibilidad', 'Movilidad y flexibilidad corporal');
go

-- 4. ENTRENADORES

insert into Personas.Entrenador
    (Nombres, Apellidos, DUI, Telefono, Correo)
values
    ('Carlos', 'Ramírez', 'SIM-ENT-001', '70000001', 'entrenador01@gymmanager.test'),
    ('Andrea', 'López', 'SIM-ENT-002', '70000002', 'entrenador02@gymmanager.test'),
    ('Daniel', 'Martínez', 'SIM-ENT-003', '70000003', 'entrenador03@gymmanager.test'),
    ('Sofía', 'Hernández', 'SIM-ENT-004', '70000004', 'entrenador04@gymmanager.test'),
    ('José', 'Castro', 'SIM-ENT-005', '70000005', 'entrenador05@gymmanager.test'),
    ('María', 'Flores', 'SIM-ENT-006', '70000006', 'entrenador06@gymmanager.test'),
    ('Luis', 'Mendoza', 'SIM-ENT-007', '70000007', 'entrenador07@gymmanager.test'),
    ('Valeria', 'Rivera', 'SIM-ENT-008', '70000008', 'entrenador08@gymmanager.test'),
    ('Miguel', 'Torres', 'SIM-ENT-009', '70000009', 'entrenador09@gymmanager.test'),
    ('Camila', 'García', 'SIM-ENT-010', '70000010', 'entrenador10@gymmanager.test');
go

--Asignar las especialidades a los entrenadores.

use GymManager;
go

insert into Clases.EntrenadorEspecialidad
    (IdEntrenador, IdEspecialidad)
values
    (1, 1), (1, 2),
    (2, 3), (2, 8),
    (3, 1), (3, 7),
    (4, 3), (4, 5),
    (5, 4), (5, 7),
    (6, 6), (6, 2),
    (7, 4), (7, 1),
    (8, 5), (8, 8),
    (9, 2), (9, 7),
    (10, 6), (10, 3);
go

--Agrega los socios de ejemplo.

use GymManager;
go

declare @Nombres table (
    Id int identity(1,1) primary key,
    Nombre nvarchar(60) not null
);

declare @Apellidos table (
    Id int identity(1,1) primary key,
    Apellido nvarchar(60) not null
);

insert into @Nombres (Nombre)
values
(N'Carlos'), (N'María'), (N'José'), (N'Ana'), (N'Luis'),
(N'Gabriela'), (N'José Luis'), (N'Fernanda'), (N'Miguel'), (N'Karla'),
(N'Andrés'), (N'Valeria'), (N'Francisco'), (N'Claudia'), (N'Ricardo'),
(N'Isabel'), (N'Fernando'), (N'Patricia'), (N'Javier'), (N'Andrea'),
(N'Roberto'), (N'Camila'), (N'Óscar'), (N'Daniela'), (N'Edgar');

insert into @Apellidos (Apellido)
values
(N'Hernández'), (N'Martínez'), (N'López'), (N'García'), (N'Rodríguez'),
(N'Pérez'), (N'Sánchez'), (N'Ramírez'), (N'Torres'), (N'Flores'),
(N'Rivera'), (N'Gómez'), (N'Díaz'), (N'Cruz'), (N'Morales'),
(N'Ortiz'), (N'Reyes'), (N'Castro'), (N'Vásquez'), (N'Ramos'),
(N'Mendoza'), (N'Aguilar'), (N'Guardado'), (N'Chávez'), (N'Fuentes');

declare @i int = 1;
declare @Nombre nvarchar(60);
declare @Apellido nvarchar(60);

while @i <= 250
begin
    select @Nombre = Nombre
    from @Nombres
    where Id = ((@i - 1) % 25) + 1;

    select @Apellido = Apellido
    from @Apellidos
    where Id = ((@i * 7 - 1) % 25) + 1;

    insert into Personas.Socio (
        Nombres,
        Apellidos,
        DUI,
        FechaNacimiento,
        Telefono,
        Correo,
        Estado
    )
    values (
        @Nombre,
        @Apellido,
        CONCAT('SIM-SOC-', right('000' + cast(@i as varchar(3)), 3)),
        dateadd(DAY, -(6570 + ((@i * 37) % 15330)), convert(date, getdate())),
        CONCAT('6000', right('0000' + cast(@i as varchar(4)), 4)),
        CONCAT('socio', @i, '@gymmanager.test'),
        case when @i % 10 = 0 then 'Inactivo' else 'Activo' end
    );

    set @i += 1;
end;
go

--Prepara las membresías y sus pagos.

use GymManager;
go

set nocount on;
set xact_abort on;

begin try
    begin transaction;

    -- 1. COMPROBAR QUE LA CARGA SEA SEGURA

    if (select count(*) from Personas.Socio) <> 250
        throw 50100, 'Se esperaban exactamente 250 socios.', 1;

    if exists (select 1 from Membresias.Membresia)
       or exists (select 1 from Membresias.Pago)
        throw 50101, 'Ya existen membresías o pagos. Se cancela la carga.', 1;

    if (select count(*) from Membresias.TipoMembresia) <> 3
        throw 50102, 'El catálogo de membresías no tiene los 3 planes esperados.', 1;

    declare @Hoy date = convert(date, getdate());

    -- 2. IDENTIFICAR LOS 125 SOCIOS
    -- QUE TENDRÁN MEMBRESÍA ACTIVA

    create table #Activos125 (
        IdSocio int primary key
    );

    insert into #Activos125 (IdSocio)
    select top (125) IdSocio
    from Personas.Socio
    where Estado = 'Activo'
      and IdSocio <= 150
    order by IdSocio;

    if (select count(*) from #Activos125) <> 125
        throw 50103, 'No hay suficientes socios activos para esta distribución.', 1;

    -- 3. PREPARAR LAS 400 MEMBRESÍAS

    create table #DatosMembresia (
        Numero int not null,
        IdSocio int not null,
        IdTipoMembresia int not null,
        Precio decimal(10,2) not null,
        Estado nvarchar(15) not null,
        FechaInicio date not null,
        FechaVencimiento date not null
    );

    ;with Numeros as (
        select top (400)
            row_number() over (order by (select null)) as N
        from sys.all_objects A
        cross join sys.all_objects B
    ),
    Distribucion as (
        select
            N,
            case
                when N % 20 between 1 and 8 then 1
                when N % 20 between 9 and 15 then 2
                else 3
            end as IdTipoMembresia,

            case
                when N <= 250 then N
                else N - 250
            end as IdSocio
        from Numeros
    ),
    Planes as (
        select
            D.N,
            D.IdSocio,
            D.IdTipoMembresia,
            T.DuracionMeses,
            T.Precio
        from Distribucion D
        inner join Membresias.TipoMembresia T
            on T.IdTipoMembresia = D.IdTipoMembresia
    ),
    Estados as (
        select
            P.*,
            case
                when P.N > 250
                     and exists (
                         select 1
                         from #Activos125 A
                         where A.IdSocio = P.IdSocio
                     )
                    then 'Activa'
                else 'Vencida'
            end as EstadoMembresia
        from Planes P
    ),
    Fechas as (
        select
            E.*,
            case
                -- Membresías anteriores de socios renovados
                when E.N <= 150
                    then dateadd(
                        day,
                        (E.N * 7) % 25,
                        dateadd(
                            month,
                            -(E.DuracionMeses + 8 + (E.N % 4)),
                            @Hoy
                        )
                    )

                -- Membresías activas más recientes
                when E.EstadoMembresia = 'Activa'
                    then dateadd(
                        day,
                        E.N % 25,
                        dateadd(
                            month,
                            -E.DuracionMeses,
                            @Hoy
                        )
                    )

                -- Membresías vencidas más recientes
                else dateadd(
                    day,
                    (E.N * 7) % 25,
                    dateadd(
                        month,
                        -(E.DuracionMeses + 1 + (E.N % 4)),
                        @Hoy
                    )
                )
            end as Inicio
        from Estados E
    )
    insert into #DatosMembresia (
        Numero,
        IdSocio,
        IdTipoMembresia,
        Precio,
        Estado,
        FechaInicio,
        FechaVencimiento
    )
    select
        N,
        IdSocio,
        IdTipoMembresia,
        Precio,
        EstadoMembresia,
        Inicio,
        dateadd(month, DuracionMeses, Inicio)
    from Fechas;

    -- 4. INSERTAR MEMBRESÍAS

    create table #MembresiasGeneradas (
        IdMembresia int,
        IdSocio int,
        FechaInicio date,
        Precio decimal(10,2)
    );

    insert into Membresias.Membresia (
        IdSocio,
        IdTipoMembresia,
        FechaInicio,
        FechaVencimiento,
        PrecioContratado,
        Estado
    )
    OUTPUT
        INSERTED.IdMembresia,
        INSERTED.IdSocio,
        INSERTED.FechaInicio,
        INSERTED.PrecioContratado
    into #MembresiasGeneradas
    select
        IdSocio,
        IdTipoMembresia,
        FechaInicio,
        FechaVencimiento,
        Precio,
        Estado
    from #DatosMembresia
    order by Numero;

    -- 5. INSERTAR UN PAGO COMPLETO POR MEMBRESÍA

    insert into Membresias.Pago (
        IdMembresia,
        FechaHoraPago,
        Monto,
        MetodoPago,
        Estado,
        Referencia
    )
    select
        M.IdMembresia,
        dateadd(HOUR, 12, cast(M.FechaInicio as datetime2(0))),
        M.Precio,
        case M.IdMembresia % 3
            when 0 then 'Efectivo'
            when 1 then 'Tarjeta'
            else 'Transferencia'
        end,
        'Pagado',
        CONCAT('SIM-PAG-', M.IdMembresia)
    from #MembresiasGeneradas M;

    -- 6. COMPROBAR CANTIDADES

    if (select count(*) from Membresias.Membresia) <> 400
        throw 50104, 'La cantidad de membresías no coincide.', 1;

    if (select count(*) from Membresias.Pago) <> 400
        throw 50105, 'La cantidad de pagos no coincide.', 1;

    commit transaction;

    select
        'Membresías' as Registro,
        count(*) as Total
    from Membresias.Membresia

    union all

    select
        'Pagos',
        count(*)
    from Membresias.Pago;

end try
begin catch

    if @@TRANCOUNT > 0
        rollback transaction;

    throw;

end catch;
go

--Revisar como quedaron repartidos los datos.

use GymManager;
go

-- 1. Distribución por plan
select
    T.Nombre as NombrePlan,
    count(*) as Total
from Membresias.Membresia M
inner join Membresias.TipoMembresia T
    on M.IdTipoMembresia = T.IdTipoMembresia
group by T.Nombre
order by T.Nombre;
go

-- 2. Distribución por estado
select
    Estado,
    count(*) as Total
from Membresias.Membresia
group by Estado;
go

-- 3. Verificar pagos completos
select
    count(*) as TotalPagos,
    sum(P.Monto) as IngresosHistoricos,
    sum(
        case
            when P.Monto = M.PrecioContratado then 1
            else 0
        end
    ) as PagosCompletos
from Membresias.Pago P
inner join Membresias.Membresia M
    on P.IdMembresia = M.IdMembresia
where P.Estado = 'Pagado';
go

--Cream las sesiones de clase.

use GymManager;
go

set nocount on;
set xact_abort on;

begin try
    begin transaction;

    if exists (select 1 from Clases.SesionClase)
        throw 50200, 'Ya existen sesiones. Se cancela la carga.', 1;

    if (select count(*) from Personas.Entrenador
        where Estado = 'Activo') <> 10
        throw 50201, 'Se esperaban 10 entrenadores activos.', 1;

    if (select count(*) from Clases.TipoClase
        where Estado = 'Activo') <> 6
        throw 50202, 'Se esperaban 6 tipos de clase activos.', 1;

    declare @Hoy date = convert(date, getdate());

    ;with Numeros as (
        select top (400)
            row_number() over (order by (select null)) as N
        from sys.all_objects A
        cross join sys.all_objects B
    ),
    Datos as (
        select
            N,
            dateadd(
                day,
                ((N - 1) % 372),
                dateadd(day, -350, @Hoy)
            ) as FechaSesion,

            case
                when N % 20 between 1 and 5 then 1
                when N % 20 between 6 and 9 then 2
                when N % 20 between 10 and 13 then 3
                when N % 20 between 14 and 16 then 4
                when N % 20 = 17 then 5
                else 6
            end as IdTipoClase,

            ((N - 1) % 10) + 1 as IdEntrenador,

            case N % 5
                when 0 then '06:00'
                when 1 then '08:00'
                when 2 then '10:00'
                when 3 then '16:00'
                else '18:00'
            end as HoraTexto,

            case N % 4
                when 0 then 10
                when 1 then 15
                when 2 then 20
                else 25
            end as Capacidad
        from Numeros
    )
    insert into Clases.SesionClase (
        IdTipoClase,
        IdEntrenador,
        Fecha,
        HoraInicio,
        HoraFin,
        CapacidadMaxima,
        Estado
    )
    select
        D.IdTipoClase,
        D.IdEntrenador,
        D.FechaSesion,
        convert(time(0), D.HoraTexto),
        convert(
            time(0),
            dateadd(
                MINUTE,
                T.DuracionMinutos,
                convert(time(0), D.HoraTexto)
            )
        ),
        D.Capacidad,
        case
            when D.FechaSesion < @Hoy then 'Finalizada'
            else 'Programada'
        end
    from Datos D
    inner join Clases.TipoClase T
        on T.IdTipoClase = D.IdTipoClase;

    if (select count(*) from Clases.SesionClase) <> 400
        throw 50203, 'No se generaron las 400 sesiones esperadas.', 1;

    commit transaction;

    select
        count(*) as TotalSesiones
    from Clases.SesionClase;

end try
begin catch

    if @@TRANCOUNT > 0
        rollback transaction;

    throw;

end catch;
go

--Reservas de ejemplo. 

use GymManager;
go

set nocount on;
set xact_abort on;

begin try
    begin transaction;

    declare @Hoy date = convert(date, getdate());

    -- 1. COMPROBACIONES INICIALES

    if exists (select 1 from Clases.Reserva)
        throw 50300, 'Ya existen reservas. Se cancela la carga.', 1;

    if (select count(*) from Clases.SesionClase) <> 400
        throw 50301, 'Se esperaban 400 sesiones.', 1;

    -- 2. OBTENER COMBINACIONES VÁLIDAS

    select
        S.IdSesion,
        M.IdSocio,
        S.Fecha,
        S.HoraFin,
        S.CapacidadMaxima,
        case
            when S.Estado = 'Finalizada' then 'Historica'
            else 'Futura'
        end as TipoGrupo,

        row_number() over (
            partition by S.IdSesion
            order by
                checksum(CONCAT(S.IdSesion, '-', M.IdSocio)),
                M.IdSocio
        ) as PosicionSesion

    into #Candidatas

    from Clases.SesionClase S

    inner join Membresias.Membresia M
        on S.Fecha >= M.FechaInicio
       and S.Fecha < M.FechaVencimiento

    inner join Personas.Socio SO
        on M.IdSocio = SO.IdSocio

    where M.Estado = 'Activa'
      and SO.Estado = 'Activo'
      and (
            S.Estado = 'Finalizada'
            or (
                S.Estado = 'Programada'
                and S.Fecha >= @Hoy
            )
          )
      and exists (
            select 1
            from Membresias.Pago P
            where P.IdMembresia = M.IdMembresia
              and P.Estado = 'Pagado'
              and P.Monto = M.PrecioContratado
      );

    -- 3. COMPROBAR CAPACIDAD POR SESIÓN

    delete from #Candidatas
    where PosicionSesion > CapacidadMaxima;

    -- 4. DISTRIBUIR CANDIDATOS

    select
        *,
        row_number() over (
            partition by TipoGrupo
            order by
                PosicionSesion,
                checksum(CONCAT(IdSocio, '-', IdSesion)),
                IdSesion,
                IdSocio
        ) as OrdenGrupo
    into #CandidatasOrdenadas
    from #Candidatas;

    -- 5. SELECCIONAR 2,200 HISTÓRICAS
    -- Y 300 FUTURAS

    select *
    into #ReservasSeleccionadas
    from #CandidatasOrdenadas
    where
        (TipoGrupo = 'Historica' and OrdenGrupo <= 2200)
        or
        (TipoGrupo = 'Futura' and OrdenGrupo <= 300);

    if (select count(*) from #ReservasSeleccionadas) <> 2500
        throw 50302, 'No existen suficientes combinaciones válidas para generar las 2500 reservas.', 1;

    -- 6. ASIGNAR ESTADOS

    select
        *,
        case
            when TipoGrupo = 'Futura'
                then 'Reservada'
            when OrdenGrupo <= 1450
                then 'Asistió'
            when OrdenGrupo <= 2000
                then 'No asistió'
            else 'Cancelada'
        end as EstadoReserva
    into #ReservasFinales
    from #ReservasSeleccionadas;

    -- 7. INSERTAR LAS RESERVAS

    insert into Clases.Reserva (
        IdSocio,
        IdSesion,
        FechaReserva,
        Estado,
        FechaAsistencia
    )
    select
        IdSocio,
        IdSesion,

        dateadd(
            day,
            -(1 + (OrdenGrupo % 14)),
            cast(Fecha as datetime2(0))
        ),

        EstadoReserva,

        case
            when EstadoReserva = 'Asistió'
            then dateadd(
                SECOND,
                datediff(
                    SECOND,
                    cast('00:00:00' as time),
                    HoraFin
                ),
                cast(Fecha as datetime2(0))
            )
            else null
        end

    from #ReservasFinales;

    -- 8. VERIFICACIONES ANTES DE CONFIRMAR

    if (select count(*) from Clases.Reserva) <> 2500
        throw 50303, 'La cantidad de reservas no coincide.', 1;

    if exists (
        select IdSesion
        from Clases.Reserva
        where Estado <> 'Cancelada'
        group by IdSesion
        having count(*) > (
            select CapacidadMaxima
            from Clases.SesionClase S
            where S.IdSesion = Clases.Reserva.IdSesion
        )
    )
        throw 50304, 'Se ha superado la capacidad de una sesión.', 1;

    commit transaction;

    select
        'Reservas generadas correctamente' as Resultado,
        count(*) as TotalReservas
    from Clases.Reserva;

end try
begin catch

    if @@TRANCOUNT > 0
        rollback transaction;

    throw;

end catch;
go

-- 6. Vistas que usa Power BI
--Vistas que se conectan con Power BI.

use GymManager;
go


use GymManager;
go

create or alter view BI.vw_MembresiasProximas
as
select
    row_number() over (
        order by M.FechaVencimiento, M.IdMembresia
    ) as NumeroOrden,

    M.IdMembresia,
    S.IdSocio,
    S.Nombres,
    S.Apellidos,
    T.Nombre as NombreMembresia,
    M.FechaInicio,
    M.FechaVencimiento,

    datediff(
        day,
        convert(date, getdate()),
        M.FechaVencimiento
    ) as DiasRestantes,

    count(*) over () as TotalProximasVencer

from Membresias.Membresia M

inner join Personas.Socio S
    on M.IdSocio = S.IdSocio

inner join Membresias.TipoMembresia T
    on M.IdTipoMembresia = T.IdTipoMembresia

where M.Estado = 'Activa'
  and M.FechaVencimiento >= convert(date, getdate())
  and M.FechaVencimiento <= dateadd(
        day,
        30,
        convert(date, getdate())
    );
go

use GymManager;
go

create or alter view BI.vw_IngresosMensuales
as
with Meses as (
    select
        dateadd(
            month,
            -N,
            datefromparts(
                year(getdate()),
                month(getdate()),
                1
            )
        ) as InicioMes
    from (values
        (0), (1), (2), (3), (4), (5),
        (6), (7), (8), (9), (10), (11)
    ) as V(N)
),
Ingresos as (
    select
        M.InicioMes,
        coalesce(sum(P.Monto), 0) as Ingresos
    from Meses M
    left join Membresias.Pago P
        on P.FechaHoraPago >= M.InicioMes
        and P.FechaHoraPago < dateadd(
            month, 1, M.InicioMes
        )
        and P.Estado = 'Pagado'
    group by M.InicioMes
),
Comparacion as (
    select
        InicioMes,
        Ingresos,
        lag(Ingresos) over (
            order by InicioMes
        ) as IngresosMesAnterior
    from Ingresos
)
select
    InicioMes,
    year(InicioMes) as Anio,
    month(InicioMes) as NumeroMes,
    Ingresos,
    IngresosMesAnterior,

    Ingresos - IngresosMesAnterior as DiferenciaMensual,

    case
        when IngresosMesAnterior is null
          or IngresosMesAnterior = 0
            then null
        else cast(
            (
                (Ingresos - IngresosMesAnterior) * 100.0
            ) / IngresosMesAnterior
            as decimal(10,2)
        )
    end as PorcentajeVariacion

from Comparacion;
go

use GymManager;
go

create or alter view BI.vw_PopularidadClases
as
with ReservasPorSesion as (
    select
        IdSesion,

        sum(case
            when Estado <> 'Cancelada' then 1
            else 0
        end) as TotalReservas,

        sum(case
            when Estado = 'Asistió' then 1
            else 0
        end) as TotalAsistencias,

        sum(case
            when Estado = 'No asistió' then 1
            else 0
        end) as TotalInasistencias,

        sum(case
            when Estado = 'Cancelada' then 1
            else 0
        end) as TotalCancelaciones

    from Clases.Reserva
    group by IdSesion
),
Estadisticas as (
    select
        T.IdTipoClase,
        T.Nombre as TipoClase,

        sum(case
            when S.Estado = 'Finalizada' then 1
            else 0
        end) as TotalSesiones,

        sum(coalesce(R.TotalReservas, 0)) as TotalReservas,
        sum(coalesce(R.TotalAsistencias, 0)) as TotalAsistencias,
        sum(coalesce(R.TotalInasistencias, 0)) as TotalInasistencias,
        sum(coalesce(R.TotalCancelaciones, 0)) as TotalCancelaciones

    from Clases.TipoClase T
    left join Clases.SesionClase S
        on T.IdTipoClase = S.IdTipoClase
    left join ReservasPorSesion R
        on S.IdSesion = R.IdSesion
    group by
        T.IdTipoClase,
        T.Nombre
),
Porcentajes as (
    select
        *,
        case
            when TotalAsistencias + TotalInasistencias = 0
                then 0
            else cast(
                TotalAsistencias * 100.0 /
                (TotalAsistencias + TotalInasistencias)
                as decimal(10,2)
            )
        end as PorcentajeAsistencia
    from Estadisticas
)
select
    IdTipoClase,
    TipoClase,
    TotalSesiones,
    TotalReservas,
    TotalAsistencias,
    TotalInasistencias,
    TotalCancelaciones,
    PorcentajeAsistencia,

    rank() over (
        order by TotalReservas desc
    ) as RankingPopularidad,

    cast(
        TotalReservas * 100.0 /
        nullif(sum(TotalReservas) over (), 0)
        as decimal(10,2)
    ) as PorcentajeReservas

from Porcentajes;
go

-- Vistas adicionales para indicadores generales del dashboard.
use GymManager;
go

create or alter view BI.vw_MembresiasActivas
as
select
    count(*) as TotalMembresiasActivas
from Membresias.Membresia
where Estado = 'Activa'
  and FechaInicio <= cast(getdate() as date)
  and FechaVencimiento > cast(getdate() as date);
go

use GymManager;
go

create or alter view BI.vw_TotalSocios
as
select count(*) as TotalSocios
from Personas.Socio;
go

use GymManager;
go

create or alter view BI.vw_TotalReservas
as
select count(*) as TotalReservas
from Clases.Reserva;
go

-- 7. Roles y permisos para cada tipo de usuario
-- Primero se crean los roles y después se asignan los permisos.

use GymManager;
go

create ROLE Gym_Admin;
create ROLE Gym_Recepcion;
create ROLE Gym_Entrenador;
create ROLE Gym_AnalistaBI;
go

select
    name as Rol,
    type_desc as Tipo
from sys.database_principals
where type = 'R'
  and name like 'Gym_%'
order by name;
go

--Asignar los permisos según lo que puede hacer cada tipo de usuario.

use GymManager;
go

-- ADMINISTRADOR: control completo de los esquemas
grant control on schema::Personas to Gym_Admin;
grant control on schema::Membresias to Gym_Admin;
grant control on schema::Clases to Gym_Admin;
grant control on schema::BI to Gym_Admin;

-- RECEPCIÓN: consultar y gestionar socios
grant select, insert, update
on schema::Personas to Gym_Recepcion;

-- RECEPCIÓN: consultar membresías y pagos
grant select
on schema::Membresias to Gym_Recepcion;

grant execute on object::Membresias.sp_RegistrarPago
to Gym_Recepcion;

grant execute on object::Clases.sp_RegistrarReserva
to Gym_Recepcion;

grant execute on object::Clases.sp_CancelarReserva
to Gym_Recepcion;

-- RECEPCIÓN: consultar clases y sesiones
grant select on schema::Clases to Gym_Recepcion;

-- ENTRENADOR: consultar sesiones y registrar asistencias
grant select on object::Clases.SesionClase
to Gym_Entrenador;

grant select on object::Clases.Reserva
to Gym_Entrenador;

grant execute on object::Clases.sp_RegistrarAsistencia
to Gym_Entrenador;

-- ANALISTA BI: consultar exclusivamente las vistas analíticas
grant select on object::BI.vw_MembresiasProximas
to Gym_AnalistaBI;

grant select on object::BI.vw_IngresosMensuales
to Gym_AnalistaBI;

grant select on object::BI.vw_PopularidadClases
to Gym_AnalistaBI;

grant select on object::BI.vw_MembresiasActivas
to Gym_AnalistaBI;

grant select on object::BI.vw_TotalSocios
to Gym_AnalistaBI;

grant select on object::BI.vw_TotalReservas
to Gym_AnalistaBI;
go

-- Usuarios de prueba sin login para comprobar los permisos.

use GymManager;
go

create user Usuario_Admin without login;
create user Usuario_Recepcion without login;
create user Usuario_Entrenador without login;
create user Usuario_AnalistaBI without login;
go

alter ROLE Gym_Admin
add MEMBER Usuario_Admin;

alter ROLE Gym_Recepcion
add MEMBER Usuario_Recepcion;

alter ROLE Gym_Entrenador
add MEMBER Usuario_Entrenador;

alter ROLE Gym_AnalistaBI
add MEMBER Usuario_AnalistaBI;
go

select
    R.name as Rol,
    U.name as Usuario
from sys.database_role_members RM
inner join sys.database_principals R
    on RM.role_principal_id = R.principal_id
inner join sys.database_principals U
    on RM.member_principal_id = U.principal_id
where R.name like 'Gym_%'
order by R.name;
go

-- Usuario de conexión real de Power BI.
-- Requisito previo: el login de servidor [LoginPowerBI] debe existir.
-- La contraseña del login se administra en SQL Server y no se almacena en este archivo.
if suser_id(N'LoginPowerBI') is not null
   and user_id(N'Usuario_PowerBI') is null
begin
    create user Usuario_PowerBI for LOGIN LoginPowerBI;
end;
go

if user_id(N'Usuario_PowerBI') is not null
   and not exists (
       select 1
       from sys.database_role_members RM
       inner join sys.database_principals R on R.principal_id = RM.role_principal_id
       inner join sys.database_principals U on U.principal_id = RM.member_principal_id
       where R.name = N'Gym_AnalistaBI'
         and U.name = N'Usuario_PowerBI'
   )
begin
    alter ROLE Gym_AnalistaBI add MEMBER Usuario_PowerBI;
end;
go

-- 8. AUDITORÍA DE SEGURIDAD
-- SQL Server Audit guarda los eventos en archivos del servidor.
use master;
go

if not exists (
    select 1
    from sys.server_audits
    where name = N'GymManager_Audit'
)
begin
    create server AUDIT GymManager_Audit
    to file
    (
        filepath = '/var/opt/mssql/log/',
        maxsize = 50 MB,
        max_rollover_files = 10
    )
    with (ON_FAILURE = continue);
end;
go

alter server AUDIT GymManager_Audit
with (state = on);
go

use GymManager;
go

if not exists (
    select 1
    from sys.database_audit_specifications
    where name = N'GymManager_DB_Audit'
)
begin
    create database AUDIT SPECIFICATION GymManager_DB_Audit
    for server AUDIT GymManager_Audit
        add (select on object::Personas.Socio by public),
        add (insert on object::Personas.Socio by public),
        add (update on object::Personas.Socio by public),
        add (insert on object::Membresias.Pago by public),
        add (update on object::Membresias.Pago by public),
        add (insert on object::Membresias.Membresia by public),
        add (update on object::Membresias.Membresia by public),
        add (insert on object::Clases.Reserva by public),
        add (update on object::Clases.Reserva by public)
    with (state = on);
end;
go

alter database AUDIT SPECIFICATION GymManager_DB_Audit
with (state = on);
go
