-- Step 1: Creating the Function
-- Ensuring previous function is dropped before creating a new one
IF OBJECT_ID('dbo.FormatDate', 'FN') IS NOT NULL
    DROP FUNCTION dbo.FormatDate;
GO

CREATE FUNCTION dbo.FormatDate (@InputDate DATETIME)
RETURNS VARCHAR(10)
AS
BEGIN
    DECLARE @FormattedDate VARCHAR(10);
    SET @FormattedDate = CONVERT(VARCHAR(10), @InputDate, 101);
    RETURN @FormattedDate;
END;
GO


------------------------------------------------


-- Step 2: Testing the Function
-- Testing the FormatDate function with a sample datetime
SELECT dbo.FormatDate('2006-11-21 23:34:05.920') AS FormattedDate;


-- Step 1: Creating the Function
-- Ensuring previous function is dropped before creating a new one
IF OBJECT_ID('dbo.FormatDateYYYYMMDD', 'FN') IS NOT NULL
    DROP FUNCTION dbo.FormatDateYYYYMMDD;
GO

CREATE FUNCTION dbo.FormatDateYYYYMMDD (@InputDate DATETIME)
RETURNS VARCHAR(8)
AS
BEGIN
    DECLARE @FormattedDate VARCHAR(8);
    SET @FormattedDate = CONVERT(VARCHAR(8), @InputDate, 112);
    RETURN @FormattedDate;
END;
GO


------------------------------------------------


-- Step 2: Testing the Function
-- Testing the FormatDateYYYYMMDD function with a sample datetime
SELECT dbo.FormatDateYYYYMMDD('2006-11-21 23:34:05.920') AS FormattedDate;


-- Step 1 : Creating Sample Tables and Inserting Data
-- Creating the Products table
CREATE TABLE Products (
    ProductID INT PRIMARY KEY,
    Name NVARCHAR(50),
    UnitPrice DECIMAL(18, 2),
    UnitsInStock INT,
    ReorderLevel INT
);

-- Creating the Order Details table
CREATE TABLE [Order Details] (
    OrderDetailID INT IDENTITY(1,1) PRIMARY KEY,
    OrderID INT,
    ProductID INT,
    UnitPrice DECIMAL(18, 2),
    Quantity INT,
    Discount DECIMAL(4, 2)
);

-- Inserting sample data into Products table
INSERT INTO Products (ProductID, Name, UnitPrice, UnitsInStock, ReorderLevel)
VALUES
(1, 'Product A', 10.00, 100, 20),
(2, 'Product B', 20.00, 50, 10),
(3, 'Product C', 30.00, 30, 5);

-- Inserting sample data into Order Details table
INSERT INTO [Order Details] (OrderID, ProductID, UnitPrice, Quantity, Discount)
VALUES
(1, 1, 10.00, 5, 0),
(1, 2, 20.00, 2, 0),
(2, 3, 30.00, 1, 0);


-----------------------------------------------------


-- Step 2 : Creating the Stored Procedure
GO

CREATE PROCEDURE InsertOrderDetails
    @OrderID INT,
    @ProductID INT,
    @UnitPrice DECIMAL(18, 2) = NULL,
    @Quantity INT,
    @Discount DECIMAL(4, 2) = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CurrentUnitPrice DECIMAL(18, 2);
    DECLARE @UnitsInStock INT;
    DECLARE @ReorderLevel INT;

    -- Get the current UnitPrice from the Products table if not provided
    IF @UnitPrice IS NULL
    BEGIN
        SELECT @CurrentUnitPrice = UnitPrice
        FROM Products
        WHERE ProductID = @ProductID;

        IF @CurrentUnitPrice IS NULL
        BEGIN
            PRINT 'Invalid ProductID. No such product exists.';
            RETURN;
        END
    END
    ELSE
    BEGIN
        SET @CurrentUnitPrice = @UnitPrice;
    END

    -- Get the current stock and reorder level
    SELECT @UnitsInStock = UnitsInStock, @ReorderLevel = ReorderLevel
    FROM Products
    WHERE ProductID = @ProductID;

    IF @UnitsInStock IS NULL
    BEGIN
        PRINT 'Invalid ProductID. No such product exists.';
        RETURN;
    END

    -- Checking if there is enough stock
    IF @UnitsInStock < @Quantity
    BEGIN
        PRINT 'Not enough stock available to fulfill the order.';
        RETURN;
    END

    -- Inserting the order details
    INSERT INTO [Order Details] (OrderID, ProductID, UnitPrice, Quantity, Discount)
    VALUES (@OrderID, @ProductID, @CurrentUnitPrice, @Quantity, @Discount);

    -- Checking if the order was inserted successfully
    IF @@ROWCOUNT = 0
    BEGIN
        PRINT 'Failed to place the order. Please try again.';
        RETURN;
    END

    -- Updating the stock quantity
    UPDATE Products
    SET UnitsInStock = UnitsInStock - @Quantity
    WHERE ProductID = @ProductID;

    -- Checking if the stock quantity has dropped below the reorder level
    IF @UnitsInStock - @Quantity < @ReorderLevel
    BEGIN
        PRINT 'The quantity in stock of this product has dropped below its reorder level.';
    END
END;

GO


-----------------------------------------------------


--Step 3 : Testing the Stored Procedure
-- Testing with sufficient stock
EXEC InsertOrderDetails @OrderID = 3, @ProductID = 1, @Quantity = 10;

-- Testing with insufficient stock
EXEC InsertOrderDetails @OrderID = 3, @ProductID = 2, @Quantity = 60;

-- Test with default UnitPrice and Discount
EXEC InsertOrderDetails @OrderID = 3, @ProductID = 3, @Quantity = 5;


-- Step 1: Creating Tables and inserting Data
-- Resetting and creating sample data in the Production.Product table
TRUNCATE TABLE Production.Product;
TRUNCATE TABLE Sales.SalesOrderDetail;

-- Inserting sample data into Production.Product table
-- Assuming ProductID is ProductID, Name is Name, ListPrice is ListPrice, SafetyStockLevel as UnitsInStock, and ReorderPoint as ReorderLevel
INSERT INTO Production.Product (ProductID, Name, ListPrice, SafetyStockLevel, ReorderPoint)
VALUES
(1, 'Product A', 10.00, 100, 20),
(2, 'Product B', 20.00, 50, 10),
(3, 'Product C', 30.00, 30, 5);

-- Inserting sample data into Sales.SalesOrderDetail table
-- Assuming SalesOrderID is OrderID, ProductID is ProductID, UnitPrice is UnitPrice, OrderQty as Quantity, and UnitPriceDiscount as Discount
INSERT INTO Sales.SalesOrderDetail (SalesOrderID, ProductID, UnitPrice, OrderQty, UnitPriceDiscount)
VALUES
(1, 1, 10.00, 5, 0),
(1, 2, 20.00, 2, 0),
(2, 3, 30.00, 1, 0);


------------------------------------------------------


-- Step 2: Creating the UpdateOrderDetails Stored Procedure
-- Ensuring previous procedure is dropped before creating a new one
IF OBJECT_ID('UpdateOrderDetails', 'P') IS NOT NULL
    DROP PROCEDURE UpdateOrderDetails;
GO

CREATE PROCEDURE UpdateOrderDetails
    @OrderID INT,
    @ProductID INT,
    @UnitPrice DECIMAL(18, 2) = NULL,
    @Quantity INT = NULL,
    @Discount DECIMAL(4, 2) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @OldQuantity INT;
    DECLARE @OldUnitPrice DECIMAL(18, 2);
    DECLARE @OldDiscount DECIMAL(4, 2);
    DECLARE @NewUnitPrice DECIMAL(18, 2);
    DECLARE @NewQuantity INT;
    DECLARE @NewDiscount DECIMAL(4, 2);

    -- Retrieving the existing order details
    SELECT @OldQuantity = Quantity, 
           @OldUnitPrice = UnitPrice, 
           @OldDiscount = Discount
    FROM [Order Details]
    WHERE OrderID = @OrderID AND ProductID = @ProductID;

    -- Ensuring the order detail exists
    IF @OldQuantity IS NULL
    BEGIN
        PRINT 'Invalid OrderID or ProductID. No such order detail exists.';
        RETURN;
    END

    -- Set new values, retaining old ones if NULL is provided
    SET @NewUnitPrice = ISNULL(@UnitPrice, @OldUnitPrice);
    SET @NewQuantity = ISNULL(@Quantity, @OldQuantity);
    SET @NewDiscount = ISNULL(@Discount, @OldDiscount);

    -- Updating the order details
    UPDATE [Order Details]
    SET UnitPrice = @NewUnitPrice,
        Quantity = @NewQuantity,
        Discount = @NewDiscount
    WHERE OrderID = @OrderID AND ProductID = @ProductID;

    -- Adjusting the UnitsInStock in the Products table
    DECLARE @StockAdjustment INT;
    SET @StockAdjustment = @OldQuantity - @NewQuantity;

    UPDATE Products
    SET UnitsInStock = UnitsInStock + @StockAdjustment
    WHERE ProductID = @ProductID;

    PRINT 'Order details updated successfully.';
END;
GO


------------------------------------------------------


-- Step 3: Testing the Stored Procedure
-- Testing updating only Quantity
EXEC UpdateOrderDetails @OrderID = 1, @ProductID = 1, @Quantity = 10;

-- Testing updating UnitPrice and Discount while keeping original Quantity
EXEC UpdateOrderDetails @OrderID = 1, @ProductID = 1, @UnitPrice = 15.00, @Discount = 0.05;

-- Testing updating all parameters
EXEC UpdateOrderDetails @OrderID = 1, @ProductID = 1, @UnitPrice = 12.00, @Quantity = 8, @Discount = 0.1;

-- Testing updating with no changes
EXEC UpdateOrderDetails @OrderID = 1, @ProductID = 1;

-- Step 1: Creating Sample Data
-- Ensuring tables have sample data
-- Inserting sample data into Sales.SalesOrderDetail table
IF NOT EXISTS (SELECT 1 FROM Sales.SalesOrderDetail)
BEGIN
    INSERT INTO Sales.SalesOrderDetail (SalesOrderID, ProductID, UnitPrice, OrderQty, UnitPriceDiscount)
    VALUES
    (1, 1, 10.00, 5, 0),
    (1, 2, 20.00, 2, 0),
    (2, 3, 30.00, 1, 0);
END


---------------------------------------------------


-- Step 2: Creating the GetOrderDetails Stored Procedure
-- Ensuring previous procedure is dropped before creating a new one
IF OBJECT_ID('GetOrderDetails', 'P') IS NOT NULL
    DROP PROCEDURE GetOrderDetails;
GO

CREATE PROCEDURE GetOrderDetails
    @OrderID INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Checking if there are any records for the given OrderID
    IF NOT EXISTS (SELECT 1 FROM Sales.SalesOrderDetail WHERE SalesOrderID = @OrderID)
    BEGIN
        PRINT 'The OrderID ' + CAST(@OrderID AS VARCHAR(10)) + ' does not exist.';
        RETURN 1;
    END

    -- Returning the order details for the given OrderID
    SELECT SalesOrderID AS OrderID,
           ProductID,
           UnitPrice,
           OrderQty AS Quantity,
           UnitPriceDiscount AS Discount
    FROM Sales.SalesOrderDetail
    WHERE SalesOrderID = @OrderID;
END;
GO


---------------------------------------------------


-- Step 3: Testing the Stored Procedure
-- Testing with an existing OrderID
EXEC GetOrderDetails @OrderID = 1;

-- Testing with a non-existing OrderID
EXEC GetOrderDetails @OrderID = 99;

-- Step 1: Creating Sample Data
CREATE TABLE SalesOrderDetail (
    SalesOrderID INT,
    ProductID INT,
    OrderQty INT,
    UnitPrice DECIMAL(10, 2),
    PRIMARY KEY (SalesOrderID, ProductID)
);
GO
-- Inserting sample data into the SalesOrderDetail table
INSERT INTO SalesOrderDetail (SalesOrderID, ProductID, OrderQty, UnitPrice) VALUES
(1, 100, 2, 19.99),
(1, 101, 1, 29.99),
(2, 100, 3, 19.99),
(2, 102, 1, 39.99);
GO


---------------------------------------------------


-- Step 2: Creating the DeleteOrderDetails Stored Procedure
IF OBJECT_ID('DeleteOrderDetails', 'P') IS NOT NULL
DROP PROCEDURE DeleteOrderDetails;
GO
-- Creating the DeleteOrderDetails stored procedure
CREATE PROCEDURE DeleteOrderDetails
    @SalesOrderID INT,
    @ProductID INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Checking if the SalesOrderID exists in the table
    IF NOT EXISTS (SELECT 1 FROM SalesOrderDetail WHERE SalesOrderID = @SalesOrderID)
    BEGIN
        PRINT 'Error: SalesOrderID does not exist.';
        RETURN -1;
    END

    -- Checking if the ProductID exists for the given SalesOrderID
    IF NOT EXISTS (SELECT 1 FROM SalesOrderDetail WHERE SalesOrderID = @SalesOrderID AND ProductID = @ProductID)
    BEGIN
        PRINT 'Error: ProductID does not exist for the given SalesOrderID.';
        RETURN -1;
    END

    -- Deleting the record if both SalesOrderID and ProductID are valid
    DELETE FROM SalesOrderDetail
    WHERE SalesOrderID = @SalesOrderID AND ProductID = @ProductID;

    PRINT 'Order details deleted successfully.';
    RETURN 0;
END;
GO


---------------------------------------------------


-- Step 3: Testing the Stored Procedure
EXEC DeleteOrderDetails @SalesOrderID = 1, @ProductID = 101;

-- Step 1 : Creating the Orders table and inserting sample data
IF OBJECT_ID('Orders', 'U') IS NOT NULL
DROP TABLE Orders;
GO

CREATE TABLE Orders (
    OrderID INT PRIMARY KEY,
    OrderDate DATETIME,
    CustomerID INT
);
GO

IF OBJECT_ID('OrderDetails', 'U') IS NOT NULL
DROP TABLE OrderDetails;
GO

CREATE TABLE OrderDetails (
    OrderDetailID INT PRIMARY KEY,
    OrderID INT,
    ProductID INT,
    Quantity INT,
    FOREIGN KEY (OrderID) REFERENCES Orders(OrderID)
);
GO

-- Inserting sample data into the Orders table
INSERT INTO Orders (OrderID, OrderDate, CustomerID) VALUES
(1, '2022-01-01', 101),
(2, '2022-01-02', 102),
(3, '2022-01-03', 103);
GO

-- Inserting sample data into the Order Details table
INSERT INTO OrderDetails (OrderDetailID, OrderID, ProductID, Quantity) VALUES
(1, 1, 100, 2),
(2, 1, 101, 1),
(3, 2, 100, 3),
(4, 2, 102, 1),
(5, 3, 103, 5);
GO


-------------------------------------------------------------------


-- Step 2 : Creating the Instead of Delete trigger 
CREATE TRIGGER trgInsteadOfDeleteOrder
ON Orders
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- Deleting corresponding records from OrderDetails
    DELETE FROM OrderDetails
    WHERE OrderID IN (SELECT OrderID FROM DELETED);

    -- Deleting the order from Orders table
    DELETE FROM Orders
    WHERE OrderID IN (SELECT OrderID FROM DELETED);

    PRINT 'Order and its details deleted successfully.';
END;
GO


-------------------------------------------------------------------


-- Step 3 : Testing the INSTEAD OF DELETE trigger by attempting to delete an order
DELETE FROM Orders WHERE OrderID = 2;

-- Step 1 : Creating the Products tables and inserting sample data
IF OBJECT_ID('Products', 'U') IS NOT NULL
DROP TABLE Products;
GO

CREATE TABLE Products (
    ProductID INT PRIMARY KEY,
    ProductName NVARCHAR(50),
    UnitsInStock INT
);
GO

IF OBJECT_ID('Orders', 'U') IS NOT NULL
DROP TABLE Orders;
GO

CREATE TABLE Orders (
    OrderID INT PRIMARY KEY,
    OrderDate DATETIME,
    CustomerID INT
);
GO

IF OBJECT_ID('OrderDetails', 'U') IS NOT NULL
DROP TABLE OrderDetails;
GO

CREATE TABLE OrderDetails (
    OrderDetailID INT PRIMARY KEY,
    OrderID INT,
    ProductID INT,
    Quantity INT,
    FOREIGN KEY (OrderID) REFERENCES Orders(OrderID),
    FOREIGN KEY (ProductID) REFERENCES Products(ProductID)
);
GO

-- Inserting sample data into the Products table
INSERT INTO Products (ProductID, ProductName, UnitsInStock) VALUES
(100, 'ProductA', 50),
(101, 'ProductB', 20),
(102, 'ProductC', 0);
GO

-- Inserting sample data into the Orders table
INSERT INTO Orders (OrderID, OrderDate, CustomerID) VALUES
(1, '2022-01-01', 101),
(2, '2022-01-02', 102),
(3, '2022-01-03', 103);
GO


----------------------------------------------------------------


-- Step 2 : Creating the INSTEAD OF INSERT trigger on the OrderDetails table
CREATE TRIGGER trgCheckStockBeforeInsert
ON OrderDetails
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ProductID INT, @Quantity INT, @UnitsInStock INT;

    -- Looping through each row in the inserted pseudo table
    DECLARE order_cursor CURSOR FOR
    SELECT ProductID, Quantity
    FROM inserted;

    OPEN order_cursor;

    FETCH NEXT FROM order_cursor INTO @ProductID, @Quantity;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Checking the stock
        SELECT @UnitsInStock = UnitsInStock
        FROM Products
        WHERE ProductID = @ProductID;

        -- If sufficient stock exists
        IF @UnitsInStock >= @Quantity
        BEGIN
            -- Inserting the order detail
            INSERT INTO OrderDetails (OrderDetailID, OrderID, ProductID, Quantity)
            SELECT OrderDetailID, OrderID, ProductID, Quantity
            FROM inserted;

            -- Decrementing the stock
            UPDATE Products
            SET UnitsInStock = UnitsInStock - @Quantity
            WHERE ProductID = @ProductID;
        END
        ELSE
        BEGIN
            -- Notifying the user that the order could not be filled
            RAISERROR ('Order could not be filled because of insufficient stock for ProductID %d.', 16, 1, @ProductID);
        END

        FETCH NEXT FROM order_cursor INTO @ProductID, @Quantity;
    END

    CLOSE order_cursor;
    DEALLOCATE order_cursor;
END;
GO


----------------------------------------------------------------


-- Step 3 : Testing the Trigger
-- Attempting to insert an order detail with sufficient stock
INSERT INTO OrderDetails (OrderDetailID, OrderID, ProductID, Quantity)
VALUES (1, 1, 100, 10); -- This should succeed

-- Attempting to insert an order detail with insufficient stock
INSERT INTO OrderDetails (OrderDetailID, OrderID, ProductID, Quantity)
VALUES (2, 1, 102, 10); -- This should fail and raise an error

-- Checking the results
SELECT * FROM OrderDetails;
SELECT * FROM Products;