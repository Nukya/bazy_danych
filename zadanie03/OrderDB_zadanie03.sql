USE OrderDB;
GO

--INDEKS ZGRUPOWANY I NIEZGRUPOWANY
/*
Uzasadnienie:
Indeks zgrupowany (clustered) określa fizyczną kolejność danych w tabeli
i zazwyczaj jest tworzony automatycznie przez klucz główny (PRIMARY KEY).
Indeks niezgrupowany (nonclustered) tworzy osobną strukturę,
która pozwala szybciej wyszukiwać i sortować dane po innych kolumnach.

Zastosowanie:
- Klucz główny w tabeli orders pełni rolę indeksu zgrupowanego.
- Indeks niezgrupowany na kolumnie order_date przyspiesza sortowanie i filtrowanie po dacie.
- Indeks niezgrupowany na product_id przyspiesza złączenia z tabelą products.
*/
BEGIN TRY
    BEGIN TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_orders_orderDate' AND object_id = OBJECT_ID('dbo.orders'))
        CREATE NONCLUSTERED INDEX IX_orders_orderDate ON dbo.orders(order_date);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_order_products_product' AND object_id = OBJECT_ID('dbo.order_products'))
        CREATE NONCLUSTERED INDEX IX_order_products_product ON dbo.order_products(product_id);

    --INDEKS GĘSTY I RZADKI
/*
Indeks gęsty (dense) zawiera wpis dla każdego wiersza w tabeli.
Stosowany, gdy kolumna ma niewiele wartości NULL i często występuje w zapytaniach.
Indeks rzadki (sparse) obejmuje tylko część wierszy, np. te spełniające warunek WHERE.
Pozwala zaoszczędzić miejsce i poprawić wydajność w kolumnach, które często są puste.

Zastosowanie:
- Indeks gęsty na customer_id – każdy wiersz ma klienta.
- Indeks rzadki na ship_date – obejmuje tylko zamówienia, które zostały wysłane.
*/
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_orders_customer_dense' AND object_id = OBJECT_ID('dbo.orders'))
        CREATE NONCLUSTERED INDEX IX_orders_customer_dense ON dbo.orders(customer_id);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_orders_shipped_sparse' AND object_id = OBJECT_ID('dbo.orders'))
        CREATE NONCLUSTERED INDEX IX_orders_shipped_sparse 
        ON dbo.orders(ship_date) 
        WHERE ship_date IS NOT NULL;

    ----------------------------------------------------------
    --INDEKS KOLUMNOWY
    ----------------------------------------------------------
 /*
Indeks kolumnowy (columnstore) przechowuje dane kolumnowo, a nie wierszowo.
Stosowany głównie w zapytaniach analitycznych (SUM, AVG, GROUP BY) na dużych zbiorach danych.
Zmniejsza rozmiar danych i przyspiesza przetwarzanie agregacji.

Zastosowanie:
- Indeks kolumnowy na kolumnach sales, profit i quantity w tabeli order_products
  przyspiesza raporty i analizy finansowe.
*/
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'CCI_order_products_sales' AND object_id = OBJECT_ID('dbo.order_products'))
        CREATE NONCLUSTERED COLUMNSTORE INDEX CCI_order_products_sales 
        ON dbo.order_products(sales, profit, quantity);

    COMMIT TRANSACTION;
    PRINT 'Indeksy utworzone pomyślnie.';
END TRY
BEGIN CATCH
    PRINT 'Wystąpił błąd podczas tworzenia indeksów:';
    PRINT ERROR_MESSAGE();
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
END CATCH;
GO

--PROCEDURA – Zamówienia wg podkategorii i kraju
/*
Zwraca: order id, order date, ship date, product name, sales, quantity, profit
Umożliwia pobranie wszystkich zamówień dla konkretnej podkategorii w danym kraju.
*/
IF OBJECT_ID('dbo.GetOrdersBySubcategoryAndCountry', 'P') IS NOT NULL
    DROP PROCEDURE dbo.GetOrdersBySubcategoryAndCountry
GO

CREATE PROCEDURE dbo.GetOrdersBySubcategoryAndCountry
    @SubCategoryName VARCHAR(100),
    @CountryName VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        o.id AS [Order ID],
        o.order_date AS [Order Date],
        o.ship_date AS [Ship Date],
        p.name AS [Product Name],
        op.sales AS [Sales],
        op.quantity AS [Quantity],
        op.profit AS [Profit]
    FROM dbo.orders o
    JOIN dbo.order_products op ON o.id = op.order_id
    JOIN dbo.products p ON p.id = op.product_id
    JOIN dbo.[sub_categories] s ON p.sub_category_id = s.id
    JOIN dbo.cities ci ON o.city_id = ci.id
    JOIN dbo.states st ON ci.state_id = st.id
    JOIN dbo.countries c ON st.country_id = c.id
    WHERE s.name = @SubCategoryName
      AND c.name = @CountryName
    ORDER BY o.order_date DESC;
END
GO



--PROCEDURA – Dwa najnowsze zamówienia dla segmentu Consumer

/*
Zwraca: order id, order date, product name, sales, customer name
Zwraca dwa najnowsze zamówienia dla każdego klienta z segmentu 'Consumer'.
*/
IF OBJECT_ID('dbo.GetTwoLatestOrdersForConsumerSegment', 'P') IS NOT NULL
    DROP PROCEDURE dbo.GetTwoLatestOrdersForConsumerSegment
GO

CREATE PROCEDURE dbo.GetTwoLatestOrdersForConsumerSegment
AS
BEGIN
    SET NOCOUNT ON;

    WITH RankedOrders AS (
        SELECT 
            o.id AS [Order ID],
            o.order_date AS [Order Date],
            p.name AS [Product Name],
            op.sales AS [Sales],
            cst.name AS [Customer Name],
            ROW_NUMBER() OVER (PARTITION BY cst.id ORDER BY o.order_date DESC) AS rn
        FROM dbo.orders o
        JOIN dbo.order_products op ON o.id = op.order_id
        JOIN dbo.products p ON p.id = op.product_id
        JOIN dbo.customers cst ON o.customer_id = cst.id
        JOIN dbo.segments sg ON cst.segment_id = sg.id
        WHERE sg.name = 'Consumer'
    )
    SELECT [Order ID], [Order Date], [Product Name], [Sales], [Customer Name]
    FROM RankedOrders
    WHERE rn <= 2
    ORDER BY [Customer Name], [Order Date] DESC;
END
GO

EXEC dbo.GetOrdersBySubcategoryAndCountry 'Table', 'Poland';
EXEC dbo.GetTwoLatestOrdersForConsumerSegment;