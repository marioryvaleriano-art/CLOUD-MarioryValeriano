-- =====================================================
-- SCRIPT DDL: BODEGA PEIRANO - TABLAS TRANSACCIONALES
-- Base de datos: BodegaPeiranoDBF
-- =====================================================

IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'BodegaPeiranoDBF')
BEGIN
    CREATE DATABASE BodegaPeiranoDBF;
END;
GO

USE BodegaPeiranoDBF;
GO

-- =====================================================
-- 1. TABLA: VENTA
-- =====================================================
IF OBJECT_ID('dbo.detalle_venta', 'U') IS NOT NULL DROP TABLE dbo.detalle_venta;
IF OBJECT_ID('dbo.venta', 'U') IS NOT NULL DROP TABLE dbo.venta;
IF OBJECT_ID('dbo.promocion_producto', 'U') IS NOT NULL DROP TABLE dbo.promocion_producto;
IF OBJECT_ID('dbo.promocion', 'U') IS NOT NULL DROP TABLE dbo.promocion;
GO

CREATE TABLE venta (
    id_venta INT IDENTITY(1,1) NOT NULL,
    fecha_venta DATETIME2 NOT NULL DEFAULT GETDATE(),
    tipo_documento VARCHAR(20) NOT NULL,
    numero_documento VARCHAR(20) NOT NULL,
    estado CHAR(1) NOT NULL DEFAULT 'C', -- C=Completada, A=Anulada
    total DECIMAL(10,2) NOT NULL,
    referencia_transaccion VARCHAR(100) NULL,
    id_cliente INT NOT NULL, -- Referencia lógica a MongoDB
    id_almacen INT NOT NULL, -- Referencia lógica a MongoDB
    id_metodo_pago INT NOT NULL, -- Referencia lógica a MongoDB
    CONSTRAINT venta_pk PRIMARY KEY (id_venta),
    CONSTRAINT venta_total_positivo CHECK (total > 0),
    CONSTRAINT venta_estado_check CHECK (estado IN ('C','A')),
    CONSTRAINT venta_tipo_doc_check CHECK (tipo_documento IN ('Boleta', 'Factura', 'Ticket')),
    CONSTRAINT venta_documento_unico UNIQUE (tipo_documento, numero_documento)
);
GO

-- =====================================================
-- 2. TABLA: DETALLE_VENTA
-- =====================================================
CREATE TABLE detalle_venta (
    id_detalle_venta INT IDENTITY(1,1) NOT NULL,
    id_venta INT NOT NULL,
    id_producto INT NOT NULL, -- Referencia lógica a MongoDB
    cantidad DECIMAL(10,2) NOT NULL,
    precio_unitario DECIMAL(10,2) NOT NULL,
    descuento DECIMAL(10,2) NULL DEFAULT 0,
    subtotal DECIMAL(10,2) NOT NULL,
    CONSTRAINT detalle_venta_pk PRIMARY KEY (id_detalle_venta),
    CONSTRAINT detalle_cantidad_positiva CHECK (cantidad > 0),
    CONSTRAINT detalle_subtotal_check CHECK (subtotal = (cantidad * precio_unitario) - descuento)
);
GO

-- =====================================================
-- 3. TABLA: PROMOCION
-- =====================================================
CREATE TABLE promocion (
    id_promocion INT IDENTITY(1,1) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    descripcion VARCHAR(255) NULL,
    fecha_inicio DATETIME NOT NULL,
    fecha_fin DATETIME NOT NULL,
    tipo_promocion CHAR(1) NOT NULL, -- 'P' = Porcentaje por Producto, 'K' = Pack/Combo
    descuento_porcentaje DECIMAL(5,2) NULL, -- Ej: 10.00 (para un 10%)
    monto_fijo_pack DECIMAL(10,2) NULL,    -- Si el pack tiene un precio final cerrado
    estado BIT NOT NULL DEFAULT 1,
    CONSTRAINT promocion_pk PRIMARY KEY (id_promocion),
    CONSTRAINT promocion_fechas_check CHECK (fecha_fin > fecha_inicio),
    CONSTRAINT promocion_tipo_check CHECK (tipo_promocion IN ('P', 'K')),
    CONSTRAINT promocion_valores_check CHECK (
        (tipo_promocion = 'P' AND descuento_porcentaje IS NOT NULL AND monto_fijo_pack IS NULL) OR
        (tipo_promocion = 'K' AND monto_fijo_pack IS NOT NULL)
    )
);
GO

-- =====================================================
-- 4. TABLA: PROMOCION_PRODUCTO
-- =====================================================
CREATE TABLE promocion_producto (
    id_promocion_producto INT IDENTITY(1,1) NOT NULL,
    id_promocion INT NOT NULL,
    id_producto INT NOT NULL, -- Referencia lógica a MongoDB
    cantidad_requerida INT NOT NULL DEFAULT 1,
    aplica_descuento_adicional BIT NOT NULL DEFAULT 0,
    CONSTRAINT promocion_producto_pk PRIMARY KEY (id_promocion_producto),
    CONSTRAINT promocion_producto_unico UNIQUE (id_promocion, id_producto),
    CONSTRAINT promocion_producto_cantidad_check CHECK (cantidad_requerida > 0)
);
GO

-- =====================================================
-- INSERTS: PROMOCION Y PROMOCION_PRODUCTO
-- =====================================================

-- 1. Promociones
INSERT INTO promocion (nombre, descripcion, fecha_inicio, fecha_fin, tipo_promocion, descuento_porcentaje, monto_fijo_pack, estado) 
VALUES ('Semana del Pisco', '15% desc en Piscos seleccionados', '2026-07-01', '2026-07-31', 'P', 15.00, NULL, 1);

INSERT INTO promocion (nombre, descripcion, fecha_inicio, fecha_fin, tipo_promocion, descuento_porcentaje, monto_fijo_pack, estado) 
VALUES ('Pack Fiestas Patrias', 'Pisco + 2 Sangrías + Jarabe', '2026-07-15', '2026-07-30', 'K', NULL, 50.00, 1);
GO

-- 2. Promoción Producto
INSERT INTO promocion_producto (id_promocion, id_producto, cantidad_requerida, aplica_descuento_adicional) VALUES
(1, 1, 1, 0), -- Pisco Quebranta
(1, 2, 1, 0), -- Pisco Italia
(1, 3, 1, 0); -- Pisco Acholado

INSERT INTO promocion_producto (id_promocion, id_producto, cantidad_requerida, aplica_descuento_adicional) VALUES
(2, 1, 1, 0),  -- 1 Pisco Quebranta (ID 1)
(2, 10, 2, 0), -- 2 Sangrías Tintas (ID 10)
(2, 12, 1, 0); -- 1 Jarabe de Goma (ID 12)
GO
