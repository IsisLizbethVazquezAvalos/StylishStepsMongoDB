---------------------Afectar-Inventario-------------------------------------
CREATE ALTER PROCEDURE afectar_inventario 
    @product_id INT,
    @quantity INT,
    @success BIT OUTPUT
AS
BEGIN
    BEGIN TRANSACTION
    BEGIN TRY
        DECLARE @units_in_stock INT;
        SET @success = 0;

        -- Verificar si existe el producto
        IF EXISTS (SELECT 1 FROM productos WHERE id_producto = @product_id)
        BEGIN
            -- Obtener la existencia del producto
            SELECT @units_in_stock = stock_disponible FROM productos WHERE id_producto = @product_id;

            -- Verificar que haya suficiencia en inventario
            IF @units_in_stock >= @quantity
            BEGIN
                -- Actualizar el inventario
                UPDATE productos
                SET stock_disponible = stock_disponible - @quantity
                WHERE id_producto = @product_id;

                SET @success = 1;
                COMMIT TRANSACTION;
            END
            ELSE
            BEGIN
                THROW 50001, 'Error: no hay suficiente en existencia.', 1;
            END
        END
        ELSE
        BEGIN
            THROW 50002, 'Error: el producto no existe.', 1;
        END
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SET @success = 0;
        PRINT ERROR_MESSAGE();
    END CATCH
END
GO


DECLARE @success BIT;

-- Reducir 5 unidades del producto con ID 1
EXEC afectar_inventario 
    @product_id = 1, 
    @quantity = 5, 
    @success = @success OUTPUT;

-- Verificar resultado
SELECT @success AS Resultado;

SELECT*FROM productos;
----------------------------------------------------------------------------------------

---------------Crear Orden-------------------------------------------
CREATE ALTER PROCEDURE crear_orden
    @id_cliente INT,
	@cantidad INT,
    @id_direccion INT,
    @total INT,
    @fecha DATE,
    @estado NVARCHAR(20),
    @order_id INT OUTPUT
AS
BEGIN
    BEGIN TRANSACTION
    BEGIN TRY
        -- Inicializar el valor de la variable de salida
        SET @order_id = NULL;

        -- Verificar existencia de cliente y dirección
        IF EXISTS (SELECT 1 FROM clientes WHERE id_cliente = @id_cliente) AND
           EXISTS (SELECT 1 FROM direcciones WHERE id_direccion = @id_direccion)
        BEGIN
            -- Validar que el estado del pedido sea uno válido
            IF @estado NOT IN ('PROCESANDO', 'ENTREGADO', 'DEVOLVIENDO', 'DEVUELTO', 'RETRASADO', 'CANCELADO')
            BEGIN
                THROW 50004, 'Error: El estado del pedido no es válido.', 1;
            END

            -- Validar que el total y la cantidad sean mayores a 0
            IF @total <= 0
            BEGIN
                THROW 50005, 'Error: El total debe ser mayor a 0.', 1;
            END

			
            -- Insertar en la tabla pedidos
				INSERT INTO pedidos (id_cliente, id_direccion, total, cantidad, fecha_pedido, estado_pedido)
				VALUES (@id_cliente, @id_direccion, @total, @cantidad, @fecha, @estado); 
				PRINT 'Orden creada exitosamente para el cliente.';

            -- Obtener el ID de la orden generada
            SELECT @order_id = SCOPE_IDENTITY();

            COMMIT TRANSACTION;  -- Confirmar la transacción
        END
        ELSE
        BEGIN
            -- Si no existe el cliente o dirección, se lanza un error
            THROW 50003, 'Error: cliente o dirección no válidos.', 1;
        END
    END TRY
    BEGIN CATCH
        -- En caso de error, se revierte la transacción
        ROLLBACK TRANSACTION;
        PRINT ERROR_MESSAGE();  -- Imprimir el mensaje de error
    END CATCH
END




DECLARE @order_id INT;

-- Crear una orden
EXEC crear_orden 
    @id_cliente = 2, 
    @id_direccion = 3, 
    @total = 2500, 
	@cantidad =2,
    @fecha = '2024-12-09', 
    @estado = 'PROCESANDO', 
    @order_id = @order_id OUTPUT;

-- Verificar ID de orden generada
SELECT @order_id AS OrdenGenerada;


------------------------------------------------------------------------------------------
----------------------------------Insertar Detalles------------------------------
CREATE ALTER PROCEDURE sp_insertar_detalles 
    @order_id INT,
    @id_cliente INT
AS
BEGIN
    BEGIN TRANSACTION;
    BEGIN TRY
        -- Verificar existencia del cliente
        IF EXISTS (SELECT 1 FROM clientes WHERE id_cliente = @id_cliente)
        BEGIN
            DECLARE @id_direccion INT;
            SELECT @id_direccion = id_direccion 
            FROM pedidos 
            WHERE id_pedido = @order_id;

            -- Validar dirección asociada al pedido
            IF @id_direccion IS NULL
            BEGIN
                THROW 50005, 'Error: No se encontró una dirección asociada al pedido.', 1;
            END

            -- Insertar productos del carrito en detalles_pedidos
            INSERT INTO detalles_pedidos (id_pedido, id_direccion, cantidad, precio_unitario, descuento)
            SELECT 
                @order_id, 
                @id_direccion, 
                cantidad, 
                precio, 
                0 
            FROM carrito 
            WHERE id_cliente = @id_cliente;

            -- Eliminar productos del carrito
            DELETE FROM carrito WHERE id_cliente = @id_cliente;

            COMMIT TRANSACTION;
        END
        ELSE
        BEGIN
            THROW 50004, 'Error: Cliente no existe.', 1;
        END
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        PRINT ERROR_MESSAGE();
    END CATCH
END
GO



--  ID 1
EXEC sp_insertar_detalles 
    @order_id = 3,
    @id_cliente = 3;


SELECT*FROM detalles_pedidos;
SELECT*FROM pedidos WHERE id_pedido = 3;
SELECT*FROM carrito;

-- Consultar detalles de la orden
SELECT * FROM detalles_pedidos WHERE id_pedido = 3;

-- Verificar que se haya vaciado el carrito del cliente
SELECT * FROM carrito WHERE id_cliente = 3;

----------------------------------------------------------------------------------------

--------------------------------------------Generar Orden-------------------------------
SELECT*FROM CARRITO;
ALTER TABLE carrito ADD cantidad INT NOT NULL DEFAULT 1;

CREATE ALTER PROCEDURE sp_generar_orden 
    @id_cliente INT,
    @id_direccion INT,
   -- @total INT,
    @fecha DATE,
    @estado NVARCHAR(20)
AS
BEGIN
    BEGIN TRANSACTION
    BEGIN TRY
        DECLARE @order_id INT;
        DECLARE @success BIT;
        DECLARE @cantidad_total INT;
		DECLARE @total INT;

		-- Calcular el total basado en los productos en el carrito
        SELECT @total = SUM(c.cantidad * p.precio)
        FROM carrito c
        INNER JOIN productos p ON c.id_producto = p.id_producto
        WHERE c.id_cliente = @id_cliente;

		 -- Calcular la cantidad total de productos en el carrito
        SELECT @cantidad_total = SUM(cantidad)
        FROM carrito
        WHERE id_cliente = @id_cliente;

		-- Verificar si hay productos en el carrito
        IF @total IS NULL OR @total <= 0
        BEGIN
            THROW 50006, 'Error: No hay productos en el carrito o el total es inválido.', 1;
        END

        -- Crear la orden
        EXEC crear_orden 
            @id_cliente = @id_cliente,
            @cantidad = @cantidad_total,  -- Cantidad total
            @id_direccion = @id_direccion,
            @total = @total,
            @fecha = @fecha,
            @estado = @estado,
            @order_id = @order_id OUTPUT;

        -- Procesar productos del carrito
        DECLARE cursor_productos CURSOR FOR
        SELECT id_producto, cantidad
        FROM carrito
        WHERE id_cliente = @id_cliente;

        OPEN cursor_productos;

        DECLARE @id_producto INT, @cantidad INT;

        FETCH NEXT FROM cursor_productos INTO @id_producto, @cantidad;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- Afectar inventario
            EXEC afectar_inventario 
                @product_id = @id_producto,
                @quantity = @cantidad,
                @success = @success OUTPUT;

            IF @success = 0
            BEGIN
                THROW 50002, 'Error: No se pudo actualizar el inventario para uno o más productos.', 1;
            END

            FETCH NEXT FROM cursor_productos INTO @id_producto, @cantidad;
        END

        CLOSE cursor_productos;
        DEALLOCATE cursor_productos;

        -- Insertar detalles de la orden
        EXEC sp_insertar_detalles 
            @order_id = @order_id,
            @id_cliente = @id_cliente;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        PRINT ERROR_MESSAGE();
    END CATCH
END
GO

-- Generar una orden completa para el cliente 1
EXEC sp_generar_orden 
    @id_cliente = 8, 
   -- @id_empleado = 2, 
    @id_direccion = 8, 
   -- @total = 2000, 
    @fecha = '2024-12-09', 
    @estado = 'PROCESANDO';


select*from carrito;
SELECT*FROM PEDIDOS;
select*from detalles_pedidos;
select*from productos;

