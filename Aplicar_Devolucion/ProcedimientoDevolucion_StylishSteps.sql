use stylishsteps;

---------------PROCEDIMIENTO ALMACENADO------------------------
---------------APLICAR UNA DEVOLUCI�N--------------------------


--1.Validar la devoluci�n
	--Verificar si el pedido existe (pedidos).
	--Revisar que el estado del pedido sea v�lido para realizar devoluciones (que est� en estado, "ENTREGADO").
	

--2. Registro de la devoluci�n:
	--Insertar un registro en la tabla devoluciones con la fecha de devoluci�n, raz�n de devoluci�n y estado inicial ("PROCESANDO").
	--Actualizar el estado del pedido en la tabla pedidos a "DEVOLVIENDO" o "DEVUELTO", seg�n corresponda.

--3. Ajuste del inventario:
	--Actualizar el stock disponible del producto en la tabla productos sumando la cantidad devuelta.



--1. VALIDAR DEVOLUCI�N.
	CREATE alter PROCEDURE ValidarDevolucion (
    @_id_pedido INT,
    @_id_cliente INT
)
AS
BEGIN
	
    -- Verificar que el pedido exista 
    IF NOT EXISTS (SELECT 1 FROM pedidos WHERE id_pedido = @_id_pedido AND id_cliente = @_id_cliente)
    BEGIN
        SELECT 'El pedido no existe o no pertenece al cliente.';
        RETURN;
    END

    -- Verificar que el pedido est� en estado entregado
    IF NOT EXISTS (SELECT 1 FROM pedidos WHERE id_pedido = @_id_pedido AND estado_pedido = 'ENTREGADO')
    BEGIN
        SELECT 'El pedido no est� en estado ENTREGADO.';
        RETURN;
    END

    SELECT 'Validaci�n exitosa.';
END;

--Pruebas

SELECT * FROM pedidos;

execute ValidarDevolucion 1, 1 
execute ValidarDevolucion 2, 2
execute ValidarDevolucion 70, 1
-----------------------------------------------------------------------------------------------------------------------------------------------------





--2. REGISTRO DE LA DEVOLUCI�N
CREATE OR ALTER PROCEDURE RegistrarDevolucion (
    @_id_pedido INT,
    @_razon NVARCHAR(100),
    @_estado NVARCHAR(30) = 'PROCESANDO'
)
AS
BEGIN
    BEGIN TRANSACTION;

    DECLARE @fecha_entrega DATETIME;
    DECLARE @dias_transcurridos INT;
    DECLARE @mensaje NVARCHAR(100);

	

    -- Obtener la fecha de entrega del pedido
    SELECT @fecha_entrega = fecha_pedido
    FROM pedidos
    WHERE id_pedido = @_id_pedido;

    -- Verificar si el pedido existe
    IF @fecha_entrega IS NULL
    BEGIN
        ROLLBACK TRANSACTION;
        SELECT 'Error: El pedido no existe o no tiene una fecha de entrega registrada.' AS mensaje;
        RETURN;
    END

    -- Calcular los d�as transcurridos desde la fecha de entrega
    SET @dias_transcurridos = DATEDIFF(DAY, @fecha_entrega, SYSDATETIME());

    -- Verificar si ya pasaron m�s de 30 d�as
    IF @dias_transcurridos > 30
    BEGIN
        ROLLBACK TRANSACTION;
        SELECT 'Error: No se puede registrar la devoluci�n porque han pasado m�s de 30 d�as desde la fecha de entrega.' AS mensaje;
        RETURN;
    END

    -- Registrar la devoluci�n
    INSERT INTO Devoluciones (id_pedido, fecha_devolucion, razon_devolucion, estado_devolucion)
    VALUES (@_id_pedido, SYSDATETIME(), @_razon, @_estado);

    -- Actualizar el estado del pedido
    UPDATE pedidos
    SET estado_pedido = 'DEVOLVIENDO'
    WHERE id_pedido = @_id_pedido;

    -- Actualizar el estado de la devoluci�n
    UPDATE devoluciones
    SET estado_devolucion = 'DEVOLVIENDO'
    WHERE id_pedido = @_id_pedido;

    IF @@ERROR <> 0
    BEGIN
        ROLLBACK TRANSACTION;
        SELECT 'Error al registrar la devoluci�n.' AS mensaje;
        RETURN;
    END

    COMMIT TRANSACTION;
    SELECT 'Devoluci�n registrada exitosamente.' AS mensaje;
END;


--Pruebas
select * from pedidos;
select * from devoluciones;
execute RegistrarDevolucion 11, 11, ''

execute RegistrarDevolucion 2, 2, ''

----------------------------------------------------------------------------------------------------------------------

--3. Actualizar inventario
CREATE ALTER PROCEDURE ActualizarInventario
    @_id_producto INT,
    @_cantidad INT
    
AS
BEGIN

	
    -- Actualizar el stock del producto
    UPDATE productos
    SET stock_disponible = stock_disponible + @_cantidad
    WHERE id_producto = @_id_producto;

    IF @@ROWCOUNT = 0
    BEGIN
        SELECT 'Error al actualizar el inventario.';
        RETURN;
    END

    SELECT 'Inventario actualizado correctamente.';
END;

--Pruebas
select * from productos;


execute ActualizarInventario 1,1

------------------------------------------------------------------------------------------------------------------------------------------------------------------

--4.APLICAR DEVOLUCI�N COMPLETA
-- Creaci�n del procedimiento almacenado AplicarDevolucion
CREATE OR ALTER PROCEDURE AplicarDevolucion
    @_id_pedido INT,
    @_id_cliente INT,
    @_id_producto INT,
    @_cantidad INT,
    @_razon NVARCHAR(100),
    @_mensaje NVARCHAR(255) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        -- Iniciar la transacci�n
        BEGIN TRANSACTION;

			DECLARE @fecha_entrega DATETIME;
			DECLARE @dias_transcurridos INT;
			DECLARE @mensaje NVARCHAR(100);

	

			-- Obtener la fecha de entrega del pedido
			SELECT @fecha_entrega = fecha_pedido
			FROM pedidos
			WHERE id_pedido = @_id_pedido;

			-- Verificar si el pedido existe
			IF @fecha_entrega IS NULL
			BEGIN
				ROLLBACK TRANSACTION;
				SELECT 'Error: El pedido no existe o no tiene una fecha de entrega registrada.' AS mensaje;
				RETURN;
			END

			-- Calcular los d�as transcurridos desde la fecha de entrega
			SET @dias_transcurridos = DATEDIFF(DAY, @fecha_entrega, SYSDATETIME());

			-- Verificar si ya pasaron m�s de 30 d�as
			IF @dias_transcurridos > 30
			BEGIN
				ROLLBACK TRANSACTION;
				SELECT 'Error: No se puede registrar la devoluci�n porque han pasado m�s de 30 d�as desde la fecha de entrega.' AS mensaje;
				RETURN;
			END
        
        -- 1. Validaci�n de la Devoluci�n
        
        -- Verificar que el pedido existe y pertenece al cliente
        IF NOT EXISTS (
            SELECT 1 
            FROM pedidos 
            WHERE id_pedido = @_id_pedido 
              AND id_cliente = @_id_cliente
        )
        BEGIN
            SET @_mensaje = 'El pedido no existe o no pertenece al cliente.';
            ROLLBACK TRANSACTION;
            RETURN;
        END
        
        -- Verificar que el pedido est� en estado 'ENTREGADO'
        IF NOT EXISTS (
            SELECT 1 
            FROM pedidos 
            WHERE id_pedido = @_id_pedido 
              AND estado_pedido = 'ENTREGADO'
        )
        BEGIN
            SET @_mensaje = 'El pedido no est� en estado ENTREGADO.';
            ROLLBACK TRANSACTION;
            RETURN;
        END
        
        -- 2. Registro de la Devoluci�n
        
        -- Insertar en la tabla devoluciones
        INSERT INTO devoluciones (id_pedido, fecha_devolucion, razon_devolucion, estado_devolucion)
        VALUES (@_id_pedido, SYSDATETIME(), @_razon, 'PROCESANDO');
        
        -- Obtener el ID de la devoluci�n reci�n insertada
        DECLARE @id_devolucion INT = SCOPE_IDENTITY();
        
        -- Actualizar el estado del pedido a 'DEVOLVIENDO'
        UPDATE pedidos
        SET estado_pedido = 'DEVOLVIENDO'
        WHERE id_pedido = @_id_pedido;
        
        -- Actualizar el estado de la devoluci�n a 'DEVOLVIENDO'
        UPDATE devoluciones
        SET estado_devolucion = 'DEVOLVIENDO'
        WHERE id_devolucion = @id_devolucion;
        
        -- 3. Actualizaci�n del Inventario
        
        -- Actualizar el stock disponible del producto
        UPDATE productos
        SET stock_disponible = stock_disponible + @_cantidad
        WHERE id_producto = @_id_producto;
        
        -- Verificar que el producto existe y se actualiz�
        IF @@ROWCOUNT = 0
        BEGIN
            SET @_mensaje = 'Error al actualizar el inventario: Producto no encontrado.';
            ROLLBACK TRANSACTION;
            RETURN;
        END
        
        -- Confirmar la transacci�n
        COMMIT TRANSACTION;
        
        -- Establecer el mensaje de �xito
        SET @_mensaje = 'Devoluci�n aplicada exitosamente.';
    END TRY
    BEGIN CATCH
        -- Manejo de errores
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        -- Obtener informaci�n del error
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        
        -- Establecer el mensaje de error
        SET @_mensaje = 'Error al aplicar la devoluci�n: ' + @ErrorMessage;
        
       
    END CATCH
END;

select * from pedidos;
select * from productos;


--Pruebas

DECLARE @msj NVARCHAR(255);

EXEC AplicarDevolucion
    @_id_pedido = 23,
    @_id_cliente = 2,
    @_id_producto = 1,
    @_cantidad = 1,
    @_razon = 'Producto defectuoso',
    @_mensaje = @msj OUTPUT;

SELECT @msj AS Resultado;


-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--Ac� s�lo insert� registros para hacer pruebas

-- Insertar Clientes
INSERT INTO clientes (nombre, apellidos, correo_electronico, telefono, pais, fecha_registro)
VALUES 
('Juan', 'P�rez', 'juan.perez@example.com', '1234567890', 'M�xico', DEFAULT),
('Mar�a', 'L�pez', 'maria.lopez@example.com', '0987654321', 'M�xico', DEFAULT);

-- Insertar Categor�as
INSERT INTO categorias (nombre_categoria, descripcion)
VALUES 
('Sandalias', 'Sandalias de cuero'),
('Botas', 'Botas de invierno');

-- Insertar Productos
INSERT INTO productos (id_categoria, nombre_producto, precio, stock_disponible, img_producto, cantidad, descontinuados, reordenar_productos)
VALUES 
(1, 'Sandalia Casual', 500, 100, NULL, 1, 0, 20),
(2, 'Bota de Invierno', 1500, 50, NULL, 1, 0, 10);

-- Insertar Direcciones
INSERT INTO direcciones (colonia, calle, cp, no_interior, no_exterior, descripcion, paqueteria)
VALUES 
('Centro', 'Av. Principal', 60000, 1, 23, 'Casa de Juan P�rez', 'DHL'),
('Norte', 'Calle Secundaria', 60001, 2, 45, 'Casa de Mar�a L�pez', 'FedEx');

-- Insertar Pedidos
INSERT INTO pedidos (id_cliente, id_direccion, cantidad, fecha_pedido, estado_pedido, total)
VALUES 
(1, 1, 2, DEFAULT, 'ENTREGADO', 1000),
(2, 2, 1, DEFAULT, 'ENTREGADO', 1500);

INSERT INTO pedidos (id_cliente, id_direccion, cantidad, fecha_pedido, estado_pedido, total)
VALUES 
(6, 1, 2, DEFAULT, 'ENTREGADO', 4000),
(3, 2, 1, DEFAULT, 'ENTREGADO', 2500),
(9, 5, 1, DEFAULT, 'ENTREGADO', 2500),
(1, 2, 1, DEFAULT, 'ENTREGADO', 2500),
(2, 2, 1, DEFAULT, 'ENTREGADO', 2500);

-- Insertar Detalles de Pedidos
INSERT INTO detalles_pedidos (id_pedido, id_direccion, cantidad, precio_unitario, descuento)
VALUES 
(1, 1, 2, 500, 0),
(2, 2, 1, 1500, 100);

-- Insertar Empleados
INSERT INTO empleados (nombre, apellidos, telefono)
VALUES 
('Carlos', 'Hern�ndez', '1112223330');

-- Insertar Empleados Asignados a Pedidos
INSERT INTO empleados_pedidos (id_empleado, id_pedido, fecha_asignacion, rol_pedido)
VALUES 
(1, 1, DEFAULT, 'Repartidor');

-- Insertar Pagos de Pedidos
INSERT INTO pagos_pedidos (id_pedido, fecha_pago, monto_pago, metodo_pago)
VALUES 
(1, DEFAULT, 1000, 'CREDITO'),
(2, DEFAULT, 1400, 'EFECTIVO');

select * from pedidos;










