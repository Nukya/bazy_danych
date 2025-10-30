USE OrderDB;
GO

/*
1) Procedura zwracająca wszystkie zamówienia z bieżącego miesiąca
   (order id, order date, product name, sales, quantity).
   Warunek miesiąca jest dynamiczny (GETDATE() pobiera bieżącą datę).
*/

IF OBJECT_ID('dbo.GetCurrentMonthOrders', 'P') IS NOT NULL
    DROP PROCEDURE dbo.GetCurrentMonthOrders;
GO

CREATE PROCEDURE dbo.GetCurrentMonthOrders
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @StartOfMonth DATE = DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1);
    DECLARE @StartOfNextMonth DATE = DATEADD(MONTH, 1, @StartOfMonth);

    SELECT
        o.id          AS [order id],
        o.order_date  AS [order date],
        p.name        AS [product name],
        op.sales      AS [sales],
        op.quantity   AS [quantity]
    FROM dbo.orders AS o
    INNER JOIN dbo.order_products AS op ON op.order_id = o.id
    INNER JOIN dbo.products AS p ON p.id = op.product_id
    WHERE o.order_date >= @StartOfMonth
      AND o.order_date <  @StartOfNextMonth
    ORDER BY o.order_date DESC, o.id;
END;
GO


/* 
2) „Zmaterializowany” widok klientów, którzy złożyli co najmniej
   jedno zamówienie (customer id, customer name, segment).
   W SQL Server realizujemy to jako WIDOK INDEKSOWANY.
*/

-- Wymagane opcje sesji dla widoków indeksowanych
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET ANSI_WARNINGS ON;
SET NUMERIC_ROUNDABORT OFF;
SET ARITHABORT ON;
GO

IF OBJECT_ID('dbo.v_CustomersWithAtLeastOneOrder', 'V') IS NOT NULL
    DROP VIEW dbo.v_CustomersWithAtLeastOneOrder;
GO

CREATE VIEW dbo.v_CustomersWithAtLeastOneOrder
WITH SCHEMABINDING
AS
    SELECT
        c.id            AS customer_id,
        c.name          AS customer_name,
        s.name          AS segment,
        COUNT_BIG(*)    AS orders_count
    FROM dbo.customers AS c
    INNER JOIN dbo.segments AS s  ON s.id = c.segment_id
    INNER JOIN dbo.orders   AS o  ON o.customer_id = c.id
    GROUP BY c.id, c.name, s.name;
GO

-- „Materializacja” poprzez unikalny klastrowany indeks
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'CIX_v_CustomersWithOrders' AND object_id = OBJECT_ID('dbo.v_CustomersWithAtLeastOneOrder'))
BEGIN
    CREATE UNIQUE CLUSTERED INDEX CIX_v_CustomersWithOrders
        ON dbo.v_CustomersWithAtLeastOneOrder (customer_id);
END
GO


/* 
3) Włączenie kompresji na wybranej strukturze
   Wybrano tabelę faktów dbo.order_products — przewidywany duży wolumen.
   Zastosowano kompresję PAGE, ponieważ:
   - łączy zalety kompresji wierszowej (ROW) oraz dodatkową kompresję słownikową stron,
   - zwykle daje lepszy współczynnik redukcji rozmiaru dla danych powtarzalnych
     (np. product_id, stałe rabaty) niż sama kompresja ROW,
*/

BEGIN TRY
    BEGIN TRAN;

    -- Kompresja PAGE dla wszystkich partycji (jeśli tabela nie jest partycjonowana – dla całości)
    IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('dbo.order_products') AND type = 'U')
    BEGIN
        ALTER TABLE dbo.order_products
        REBUILD PARTITION = ALL
        WITH (DATA_COMPRESSION = PAGE);
    END

    COMMIT TRAN;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRAN;
    THROW;
END CATCH;
GO


/* 
4) Włączenie partycjonowania
   Założenia:
   - Celem jest przyspieszenie zapytań po dacie oraz ułatwienie zarządzania
     (np. „sliding window” archiwizacji). Wybrano kolumna orders.order_date.
   - Ze względu na istniejący klucz główny na orders(id), nie zmieniam
     klastrowania tabeli, tylko tworzę PARTYCJONOWANY indeks NIEKLASTROWANY
     po order_date. 
     Daje to eliminację partycji i ułatwia operacje serwisowe,
     bez naruszania więzów obcych z order_products.
   - Partycje roczne (RANGE RIGHT) na lata 2019–2031.
*/

-- Funkcja partycjonująca po datach (granicach na początkach lat)
IF NOT EXISTS (SELECT 1 FROM sys.partition_functions WHERE name = 'pfOrdersByYear')
BEGIN
    CREATE PARTITION FUNCTION pfOrdersByYear (DATE)
    AS RANGE RIGHT FOR VALUES (
        ('2020-01-01'), ('2021-01-01'), ('2022-01-01'), ('2023-01-01'),
        ('2024-01-01'), ('2025-01-01'), ('2026-01-01'), ('2027-01-01'),
        ('2028-01-01'), ('2029-01-01'), ('2030-01-01'), ('2031-01-01')
    );
END
GO

-- Schemat partycjonowania na PRIMARY
IF NOT EXISTS (SELECT 1 FROM sys.partition_schemes WHERE name = 'psOrdersByYear')
BEGIN
    CREATE PARTITION SCHEME psOrdersByYear
    AS PARTITION pfOrdersByYear ALL TO ([PRIMARY]);
END
GO

-- Indeks nieklastrowany partycjonowany po order_date
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_orders_order_date_partitioned' AND object_id = OBJECT_ID('dbo.orders'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_orders_order_date_partitioned
        ON dbo.orders (order_date, id)
        ON psOrdersByYear(order_date);
END
GO

/* Uzasadnienie rodzaju partycjonowania:
   - Rodzaj: RANGE RIGHT po DATA (order_date), partycje roczne.
   - Praktyczne przeznaczenie:
     a) Eliminacja partycji: zapytania filtrowane WHERE order_date BETWEEN ... korzystają
        z selekcji partycji, co ogranicza skan do wybranych lat.
     b) Zarządzanie danymi: łatwe odłączanie/archiwizacja starych lat (SWITCH PARTITION).
     c) Utrzymanie indeksów: przebudowy per‑partycyjnie zamiast na całości tabeli.
*/

-- Test procedury zwracającej zamówienia z bieżącego miesiąca
EXEC dbo.GetCurrentMonthOrders;

-- Widok zmaterializowany klientów, którzy złożyli przynajmniej jedno zamówienie
SELECT customer_id, customer_name, segment FROM dbo.v_CustomersWithAtLeastOneOrder;
