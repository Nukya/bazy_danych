ALTER TABLE [dbo].[order_product]
ADD CONSTRAINT chk_quantity_value CHECK (quantity >= 0);

ALTER TABLE [dbo].[order_product]
ADD CONSTRAINT chk_discount_value CHECK (discount <= 90);

ALTER TABLE [dbo].[order]
ADD 
    CONSTRAINT uq_customer_id UNIQUE (customer_id),
    CONSTRAINT uq_order_id UNIQUE (id);