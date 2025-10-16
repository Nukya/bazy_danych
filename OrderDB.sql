-- Kinga Kondraciuk 319941
CREATE DATABASE OrderDB
GO

USE OrderDB
GO

-- Tworzenie tabel oraz relacji

CREATE TABLE categories (
    id uniqueidentifier PRIMARY KEY NOT NULL,
    name VARCHAR(100) NOT NULL
);

CREATE TABLE sub_categories (
    id uniqueidentifier PRIMARY KEY NOT NULL,
    name VARCHAR(100) NOT NULL,
    category_id uniqueidentifier NOT NULL,
    CONSTRAINT fk_sub_categories_category
        FOREIGN KEY (category_id) REFERENCES categories(id)
);

CREATE TABLE products (
    id uniqueidentifier PRIMARY KEY NOT NULL,
    name VARCHAR(100) NOT NULL,
    sub_category_id uniqueidentifier NOT NULL,
    CONSTRAINT fk_products_sub_category
        FOREIGN KEY (sub_category_id) REFERENCES sub_categories(id)
);

CREATE TABLE markets (
    id uniqueidentifier PRIMARY KEY NOT NULL,
    name VARCHAR(100) NOT NULL
);

CREATE TABLE countries (
    id uniqueidentifier PRIMARY KEY NOT NULL,
    name VARCHAR(100) NOT NULL,
    market_id uniqueidentifier NOT NULL,
    CONSTRAINT fk_countries_market
        FOREIGN KEY (market_id) REFERENCES markets(id)
);

CREATE TABLE states (
    id uniqueidentifier PRIMARY KEY NOT NULL,
    name VARCHAR(100) NOT NULL,
    country_id uniqueidentifier NOT NULL,
    CONSTRAINT fk_states_country
        FOREIGN KEY (country_id) REFERENCES countries(id)
);

CREATE TABLE cities (
    id uniqueidentifier PRIMARY KEY NOT NULL,
    name VARCHAR(100) NOT NULL,
    state_id uniqueidentifier NOT NULL,
    postal_code VARCHAR(100),
    CONSTRAINT fk_cities_state
        FOREIGN KEY (state_id) REFERENCES states(id)
);

CREATE TABLE segments (
    id uniqueidentifier PRIMARY KEY NOT NULL,
    name VARCHAR(100) NOT NULL
);

CREATE TABLE customers (
    id uniqueidentifier PRIMARY KEY NOT NULL,
    name VARCHAR(100) NOT NULL,
    segment_id uniqueidentifier NOT NULL,
    CONSTRAINT fk_customers_segment
        FOREIGN KEY (segment_id) REFERENCES segments(id)
);

CREATE TABLE ship_modes (
    id uniqueidentifier PRIMARY KEY NOT NULL,
    name VARCHAR(100) NOT NULL
);

CREATE TABLE orders (
    id uniqueidentifier PRIMARY KEY NOT NULL,
    order_date DATE NOT NULL,
    ship_date DATE,
    ship_mode_id uniqueidentifier NOT NULL,
    customer_id uniqueidentifier NOT NULL,
    city_id uniqueidentifier NOT NULL,
    CONSTRAINT fk_orders_ship_mode
        FOREIGN KEY (ship_mode_id) REFERENCES ship_modes(id),
    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id) REFERENCES customers(id),
    CONSTRAINT fk_orders_city
        FOREIGN KEY (city_id) REFERENCES cities(id)
);

CREATE TABLE order_products (
    id uniqueidentifier PRIMARY KEY NOT NULL,
    order_id uniqueidentifier NOT NULL,
    product_id uniqueidentifier NOT NULL,
    quantity INT NOT NULL,
    sales FLOAT,
    discount FLOAT,
    profit FLOAT,
    shipping_cost FLOAT NOT NULL,
    CONSTRAINT fk_order_products_order
        FOREIGN KEY (order_id) REFERENCES orders(id),
    CONSTRAINT fk_order_products_product
        FOREIGN KEY (product_id) REFERENCES products(id)
);

-- Dodanie ograniczen typu CHECK oraz UNIQUE

ALTER TABLE order_products
ADD CONSTRAINT chk_quantity_value CHECK (quantity >= 0);

ALTER TABLE order_products
ADD CONSTRAINT chk_discount_value CHECK (discount <= 90);

ALTER TABLE products
ADD CONSTRAINT uq_product_name UNIQUE (name);


-- Dodanie tabeli zamówienia

CREATE TYPE dbo.OrderItemListType AS TABLE
(
    CategoryName       VARCHAR(100)     NOT NULL,
    SubCategoryName    VARCHAR(100)     NOT NULL,
    ProductName        VARCHAR(200)     NOT NULL,
    Quantity           INT              NOT NULL,
    Discount           FLOAT            NULL,
    Sales              FLOAT            NOT NULL,
    Profit             FLOAT            NULL,
    ShippingCost       FLOAT            NOT NULL
);

-- PROCEDURA WSTAWIENIA ZAMÓWIENIA
GO

-- Deklaracja zmiennych procedury
CREATE OR ALTER PROCEDURE dbo.CreateCompleteOrder
    @OrderID        UNIQUEIDENTIFIER,
    @OrderDate      DATE,
    @ShipDate       DATE,
    @ShipModeName   VARCHAR(100),
    @CustomerID     UNIQUEIDENTIFIER,
    @CustomerName   VARCHAR(200),
    @SegmentName    VARCHAR(100),
    @MarketName     VARCHAR(100),
    @CountryName    VARCHAR(100),
    @StateName      VARCHAR(100),
    @CityName       VARCHAR(100),
    @PostalCode     VARCHAR(20),
    @Items          dbo.OrderItemListType READONLY
AS
BEGIN
    SET NOCOUNT ON; -- Wyłącza komunikaty o liczbie zmodyfikowanych wierszy

    IF NOT EXISTS (SELECT 1 FROM @Items)
    BEGIN
        RAISERROR(N'Lista pozycji zamówienia jest pusta.', 16, 1);
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @MarketID UNIQUEIDENTIFIER = (SELECT id FROM dbo.markets WHERE name = @MarketName);
        IF @MarketID IS NULL
        BEGIN
            SET @MarketID = NEWID();
            INSERT INTO dbo.markets (id, name) VALUES (@MarketID, @MarketName);
        END;

        DECLARE @CountryID UNIQUEIDENTIFIER = (SELECT id FROM dbo.countries WHERE name = @CountryName);
        IF @CountryID IS NULL
        BEGIN
            SET @CountryID = NEWID();
            INSERT INTO dbo.countries (id, name, market_id) VALUES (@CountryID, @CountryName, @MarketID);
        END;

        DECLARE @StateID UNIQUEIDENTIFIER = (SELECT id FROM dbo.states WHERE name = @StateName);
        IF @StateID IS NULL
        BEGIN
            SET @StateID = NEWID();
            INSERT INTO dbo.states (id, name, country_id) VALUES (@StateID, @StateName, @CountryID);
        END;

        DECLARE @CityID UNIQUEIDENTIFIER = (SELECT id FROM dbo.cities WHERE name = @CityName);
        IF @CityID IS NULL
        BEGIN
            SET @CityID = NEWID();
            INSERT INTO dbo.cities (id, name, state_id, postal_code)
            VALUES (@CityID, @CityName, @StateID, @PostalCode);
        END;

        -- Ustal segment klienta. Jeśli nie istnieje przydziel id i wstaw do tabeli segmentów
        DECLARE @SegmentID UNIQUEIDENTIFIER = (SELECT id FROM dbo.segments WHERE name = @SegmentName);
        IF @SegmentID IS NULL
        BEGIN
            SET @SegmentID = NEWID();
            INSERT INTO dbo.segments (id, name) VALUES (@SegmentID, @SegmentName);
        END;

        -- Jeśli klient nie został przekazany, przydziel nowe id
        IF @CustomerID IS NULL
        BEGIN
            SET @CustomerID = NEWID();
        END;

        -- Jeśli klient o podanym ID nie istnieje, utwórz go
        IF NOT EXISTS (SELECT 1 FROM dbo.customers WHERE id = @CustomerID)
        BEGIN
            INSERT INTO dbo.customers (id, name, segment_id)
            VALUES (@CustomerID, @CustomerName, @SegmentID);
        END;

        -- Odnajdź id shipmode, jeśli nie istnieje shipmode o podanej nazwie, utwórz id oraz wstaw do tabeli ship_mode

        DECLARE @ShipModeID UNIQUEIDENTIFIER = (SELECT id FROM dbo.ship_modes WHERE name = @ShipModeName);
        PRINT 'ShipModeID = ' + CONVERT(varchar(36), @ShipModeID);
        
        IF @ShipModeID IS NULL
        BEGIN
            SET @ShipModeID = NEWID();
            INSERT INTO dbo.ship_modes (id, name) VALUES (@ShipModeID, @ShipModeName);
        END;
        
        -- Jeśli order nie został przekazany, wygeneruj nowego
        IF @OrderID IS NULL
        BEGIN
            SET @OrderID = NEWID();
        END;

        -- Podsumowanie. Wstaw podane lub nowo utworzone wartości do tabeli zamówień
        INSERT INTO dbo.orders (id, order_date, ship_date, ship_mode_id, customer_id, city_id)
        VALUES (@OrderID, @OrderDate, @ShipDate, @ShipModeID, @CustomerID, @CityID);

        -- Kategorie, podkategorie i produkty. 
        ;WITH DistinctCats AS (
            SELECT DISTINCT CategoryName FROM @Items
        )
        INSERT INTO dbo.categories (id, name)
        SELECT NEWID(), CategoryName
        FROM DistinctCats c
        WHERE NOT EXISTS (SELECT 1 FROM dbo.categories WHERE name = c.CategoryName);

        ;WITH DistinctSubs AS (
            SELECT DISTINCT i.SubCategoryName, c.id AS CategoryID
            FROM @Items i
            JOIN dbo.categories c ON c.name = i.CategoryName
        )
        INSERT INTO dbo.sub_categories (id, name, category_id)
        SELECT NEWID(), SubCategoryName, CategoryID
        FROM DistinctSubs s
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.sub_categories sc
            WHERE sc.name = s.SubCategoryName AND sc.category_id = s.CategoryID
        );

        ;WITH DistinctProducts AS (
            SELECT DISTINCT i.ProductName, s.id AS SubCategoryID
            FROM @Items i
            JOIN dbo.categories c ON c.name = i.CategoryName
            JOIN dbo.sub_categories s ON s.name = i.SubCategoryName AND s.category_id = c.id
        )
        INSERT INTO dbo.products (id, name, sub_category_id)
        SELECT NEWID(), ProductName, SubCategoryID
        FROM DistinctProducts p
        WHERE NOT EXISTS (SELECT 1 FROM dbo.products pr WHERE pr.name = p.ProductName);

        -- Pozycje zamówienia
        INSERT INTO dbo.order_products (id, order_id, product_id, quantity, discount, sales, profit, shipping_cost)
        SELECT 
            NEWID(), 
            @OrderID, 
            p.id, 
            it.Quantity, 
            ISNULL(it.Discount, 0),
            it.Sales,
            it.Profit,
            it.ShippingCost
        FROM @Items it
        JOIN dbo.products p ON p.name = it.ProductName;

        COMMIT TRANSACTION;

        -- Informacja zwrotna. Podsumowanie utworzonego zamówienia
        SELECT 
            o.id AS OrderID,
            o.order_date,
            c.name AS CustomerName,
            ci.name AS CityName,
            SUM(op.sales) AS TotalSales,
            SUM(op.profit) AS TotalProfit
        FROM dbo.orders o
        JOIN dbo.customers c ON o.customer_id = c.id
        JOIN dbo.cities ci ON o.city_id = ci.id
        JOIN dbo.order_products op ON o.id = op.order_id
        WHERE o.id = @OrderID
        GROUP BY o.id, o.order_date, c.name, ci.name;

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- Zadeklarowanie wartości do procedury

DECLARE @Items dbo.OrderItemListType;

INSERT INTO @Items (CategoryName, SubCategoryName, ProductName, Quantity, Discount, Sales, Profit, ShippingCost)
VALUES
('Furniture', 'Chairs', 'Office Chair', 5, 10, 500, 150, 20),
('Technology', 'Phones', 'iPhone 15', 2, 0, 2400, 600, 10);

-- Wywołanie procedury

EXEC dbo.CreateCompleteOrder
    @OrderID = NULL,
    @OrderDate = '2025-10-12',
    @ShipDate = '2025-11-18',
    @ShipModeName = 'First Class',
    @CustomerID = NULL,
    @CustomerName = 'Inpost',
    @SegmentName = 'Corporate',
    @MarketName = 'Europe',
    @CountryName = 'Poland',
    @StateName = 'Mazowieckie',
    @CityName = 'Warsaw',
    @PostalCode = '02-642',
    @Items = @Items;
GO
