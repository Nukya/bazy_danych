CREATE TABLE [categories] (
  [id] UNIQUEIDENTIFIER PRIMARY KEY NOT NULL,
  [name] nvarchar(255) NOT NULL
)
GO

CREATE TABLE [sub_categories] (
  [id] UNIQUEIDENTIFIER PRIMARY KEY NOT NULL,
  [name] nvarchar(255) NOT NULL,
  [category_id] UNIQUEIDENTIFIER NOT NULL
)
GO

CREATE TABLE [products] (
  [id] UNIQUEIDENTIFIER PRIMARY KEY NOT NULL,
  [name] nvarchar(255) NOT NULL,
  [sub_category_id] UNIQUEIDENTIFIER NOT NULL
)
GO

CREATE TABLE [markets] (
  [id] UNIQUEIDENTIFIER PRIMARY KEY NOT NULL,
  [name] nvarchar(255) NOT NULL
)
GO

CREATE TABLE [country] (
  [id] UNIQUEIDENTIFIER PRIMARY KEY NOT NULL,
  [name] nvarchar(255) NOT NULL,
  [market_id] UNIQUEIDENTIFIER NOT NULL
)
GO

CREATE TABLE [states] (
  [id] UNIQUEIDENTIFIER PRIMARY KEY NOT NULL,
  [name] nvarchar(255) NOT NULL,
  [country_id] UNIQUEIDENTIFIER NOT NULL
)
GO

CREATE TABLE [city] (
  [id] UNIQUEIDENTIFIER PRIMARY KEY NOT NULL,
  [name] nvarchar(255) NOT NULL,
  [state_id] UNIQUEIDENTIFIER NOT NULL,
  [postal_code] INT
)
GO

CREATE TABLE [customer] (
  [id] nvarchar PRIMARY KEY NOT NULL,
  [name] nvarchar(255) NOT NULL,
  [segment_id] UNIQUEIDENTIFIER NOT NULL
)
GO

CREATE TABLE [segment] (
  [id] UNIQUEIDENTIFIER PRIMARY KEY NOT NULL,
  [name] nvarchar(255) NOT NULL
)
GO

CREATE TABLE [order] (
  [id] UNIQUEIDENTIFIER PRIMARY KEY NOT NULL,
  [order_date] date NOT NULL,
  [ship_date] date,
  [ship_mode_id] nvarchar(255),
  [customer_id] UNIQUEIDENTIFIER NOT NULL,
  [city_id] UNIQUEIDENTIFIER NOT NULL,
  [order_product_id] UNIQUEIDENTIFIER NOT NULL
)
GO

CREATE TABLE [order_product] (
  [id] UNIQUEIDENTIFIER PRIMARY KEY NOT NULL,
  [quantity] int NOT NULL,
  [product_id] UNIQUEIDENTIFIER NOT NULL,
  [sales] float,
  [discount] float,
  [profit] float,
  [shipping_cost] float NOT NULL
)
GO

CREATE TABLE [ship_mode] (
  [id] UNIQUEIDENTIFIER PRIMARY KEY NOT NULL,
  [name] nvarchar NOT NULL
)
GO

ALTER TABLE [customer] ADD FOREIGN KEY ([segment_id]) REFERENCES [segment] ([id])
GO

ALTER TABLE [country] ADD FOREIGN KEY ([market_id]) REFERENCES [markets] ([id])
GO

ALTER TABLE [states] ADD FOREIGN KEY ([country_id]) REFERENCES [country] ([id])
GO

ALTER TABLE [city] ADD FOREIGN KEY ([state_id]) REFERENCES [states] ([id])
GO

ALTER TABLE [sub_categories] ADD FOREIGN KEY ([category_id]) REFERENCES [categories] ([id])
GO

ALTER TABLE [products] ADD FOREIGN KEY ([sub_category_id]) REFERENCES [sub_categories] ([id])
GO

ALTER TABLE [order] ADD FOREIGN KEY ([city_id]) REFERENCES [city] ([id])
GO

ALTER TABLE [order] ADD FOREIGN KEY ([customer_id]) REFERENCES [customer] ([id])
GO

ALTER TABLE [order] ADD FOREIGN KEY ([ship_mode_id]) REFERENCES [ship_mode] ([id])
GO

ALTER TABLE [order] ADD FOREIGN KEY ([order_product_id]) REFERENCES [order_product] ([id])
GO

ALTER TABLE [order_product] ADD FOREIGN KEY ([product_id]) REFERENCES [products] ([id])
GO
