select * from inventory_forecasting;
ALTER TABLE inventory_forecasting
ADD COLUMN unique_storeid VARCHAR(100);
UPDATE inventory_forecasting
SET unique_storeid = CONCAT_WS('_', CAST(`Store ID` AS CHAR), CAST(Region AS CHAR));
select unique_storeid from inventory_forecasting;


-- MAKING REQUIRED TABLES
CREATE TABLE Product (
    ProductID VARCHAR(10) PRIMARY KEY,
    Category VARCHAR(50)
);

CREATE TABLE Store (
	unique_storeid VARCHAR(10) PRIMARY KEY,
    StoreID VARCHAR(10) ,
    Region VARCHAR(50)
);

CREATE TABLE Sales (
    ProductID VARCHAR(10),
    unique_storeid VARCHAR(10),
    Date DATE,
    UnitsSold INT,
    UnitsOrdered INT,
    DemandForecast FLOAT,
    WeatherCondition VARCHAR(50),
    HolidayPromotion BOOLEAN,
    CompetitorPricing FLOAT,
    Seasonality VARCHAR(20),

    PRIMARY KEY (ProductID, unique_storeid, Date),
	CONSTRAINT fk_product FOREIGN KEY (ProductID) REFERENCES Product(ProductID),
    CONSTRAINT fk_store FOREIGN KEY (unique_storeid) REFERENCES Store(unique_storeid)
   
);

CREATE TABLE PriceHistory (
    ProductID VARCHAR(10),
    unique_storeid VARCHAR(10),
    Date DATE,
    Price FLOAT,
    Discount INT,

    PRIMARY KEY (ProductID, unique_storeid, Date),

    FOREIGN KEY (ProductID) REFERENCES Product(ProductID),
    FOREIGN KEY (unique_storeid) REFERENCES Store(unique_storeid)
);

CREATE TABLE InventorySnapshot (
    ProductID VARCHAR(10),
    unique_storeid VARCHAR(10),
    Date DATE,
    InventoryLevel INT,

    PRIMARY KEY (ProductID, unique_storeid, Date),

    CONSTRAINT fk_inv_product FOREIGN KEY (ProductID) REFERENCES Product(ProductID),
    CONSTRAINT fk_inv_store FOREIGN KEY (unique_storeid) REFERENCES Store(unique_storeid)
);

INSERT INTO Product (ProductID, Category)
SELECT DISTINCT `Product ID`, Category
FROM inventory_forecasting;

INSERT INTO Store (StoreID, Region, unique_storeid)
SELECT DISTINCT `Store ID`, Region, unique_storeid
FROM inventory_forecasting;

INSERT INTO PriceHistory (ProductID, unique_storeid, Date, Price, Discount)
SELECT DISTINCT `Product ID`, unique_storeid, Date, Price, Discount
FROM inventory_forecasting;

INSERT INTO InventorySnapshot (ProductID, unique_storeid, Date, InventoryLevel)
SELECT DISTINCT `Product ID`, unique_storeid, Date, `Inventory Level`
FROM inventory_forecasting;

INSERT INTO Sales (
    ProductID, unique_storeid, Date, UnitsSold, UnitsOrdered,
    DemandForecast, WeatherCondition, HolidayPromotion,
    CompetitorPricing, Seasonality
)
SELECT DISTINCT
    `Product ID`, unique_storeid, Date, `Units Sold`, `Units Ordered`,
    `Demand Forecast`, `Weather Condition`, `Holiday/Promotion`,
    `Competitor Pricing`, Seasonality
FROM inventory_forecasting;



-- REORDER POINT ESTIMATION, Turnover Analysis 
ALTER TABLE Product
ADD COLUMN LeadTimeDays INT;

UPDATE Product
SET LeadTimeDays = 
    CASE 
        WHEN Category = 'Clothing' THEN 5
        WHEN Category = 'Toys' THEN 4
        WHEN Category = 'Electronics' THEN 7
        WHEN Category = 'Furniture' THEN 10
        WHEN Category = 'Groceries' THEN 3
        ELSE 5  -- default fallback
    END;
    
    
CREATE TABLE ProductROPandTurnover AS
-- Step 1: Calculate store-level turnover (same as before)
WITH TurnoverCalc AS (
    SELECT
        s.ProductID,
        s.unique_storeid,
        SUM(s.UnitsSold) AS TotalUnitsSold,
        ROUND(AVG(i.InventoryLevel), 2) AS AvgInventoryLevel,
        ROUND(SUM(s.UnitsSold) / NULLIF(AVG(i.InventoryLevel), 0), 2) AS StoreInventoryTurnover
    FROM Sales s
    JOIN InventorySnapshot i
        ON s.ProductID = i.ProductID
        AND s.unique_storeid = i.unique_storeid
        AND s.Date = i.Date
    WHERE s.Date BETWEEN '2022-04-01' AND '2023-03-31'
    GROUP BY s.ProductID, s.unique_storeid
),
-- ### NEW STEP 2: Average the turnover for each product across all stores ###
ProductTurnover AS (
    SELECT
        ProductID,
        AVG(StoreInventoryTurnover) AS AvgProductTurnover
    FROM TurnoverCalc
    GROUP BY ProductID
),
-- ### NEW STEP 3: Rank the new product-level turnover ###
RankedProductTurnover AS (
    SELECT *,
           NTILE(4) OVER (ORDER BY AvgProductTurnover DESC) AS ProductTurnoverQuartile
    FROM ProductTurnover
),
-- Step 4: Get store-level demand stats (same as before)
RecentDemand AS (
    SELECT
        ProductID,
        unique_storeid,
        AVG(UnitsSold) AS AvgDailyDemand,
        STDDEV_SAMP(UnitsSold) AS StdDevDailyDemand
    FROM Sales
    WHERE Date >= (SELECT MAX(Date) FROM Sales) - INTERVAL 90 DAY
    GROUP BY ProductID, unique_storeid
),
-- Step 5: Get store-level price stats (same as before)
RecentPrice AS (
    SELECT
        ProductID,
        unique_storeid,
        ROUND(AVG(Price), 2) AS AvgPrice
    FROM PriceHistory
    WHERE Date >= (SELECT MAX(Date) FROM PriceHistory) - INTERVAL 30 DAY
    GROUP BY ProductID, unique_storeid
)
-- ### FINAL SELECT (MODIFIED) ###
-- Select from the store-level, but join the product-level category
SELECT 
    tc.ProductID,
    tc.unique_storeid,
    tc.TotalUnitsSold,
    tc.AvgInventoryLevel,
    tc.StoreInventoryTurnover,       -- The store-specific turnover
    rpt.AvgProductTurnover,         -- The new product-level average
    
    -- This now uses the new PRODUCT-LEVEL rank
    CASE
        WHEN rpt.ProductTurnoverQuartile = 1 THEN 'Fast-Moving'
        WHEN rpt.ProductTurnoverQuartile = 4 THEN 'Slow-Moving'
        ELSE 'Moderate'
    END AS ProductMovementCategory, -- Renamed for clarity
    
    p.LeadTimeDays,
    rp.AvgPrice,
    
    -- ReorderPoint is still store-specific, so it uses 'rd'
    ROUND(
        (rd.AvgDailyDemand * p.LeadTimeDays) + 
        (0.84 * COALESCE(rd.StdDevDailyDemand, 0) * SQRT(p.LeadTimeDays))
    , 0) AS ReorderPoint
    
FROM TurnoverCalc tc
-- Join the new product-level rankings
LEFT JOIN RankedProductTurnover rpt ON tc.ProductID = rpt.ProductID
-- Join the store-level demand stats
LEFT JOIN RecentDemand rd ON tc.ProductID = rd.ProductID AND tc.unique_storeid = rd.unique_storeid
-- Join the product info
LEFT JOIN Product p ON tc.ProductID = p.ProductID
-- Join the store-level price stats
LEFT JOIN RecentPrice rp ON tc.ProductID = rp.ProductID AND tc.unique_storeid = rp.unique_storeid;
    

-- Low Level Detection
DELETE FROM InventorySnapshot
WHERE (ProductID, unique_storeid, Date) NOT IN (
    -- This subquery finds the latest row for each item to KEEP
    SELECT
        ProductID,
        unique_storeid,
        MaxDate
    FROM (
        -- This finds the single latest date for each item
        SELECT
            ProductID,
            unique_storeid,
            MAX(Date) AS MaxDate
        FROM
            InventorySnapshot
        GROUP BY
            ProductID, unique_storeid
    ) AS LatestRows
);

-- ---
-- Step 2: Add the LowLevelDetection column to the (now much smaller) table
-- ---
ALTER TABLE InventorySnapshot
ADD COLUMN LowLevelDetection VARCHAR(10);

-- ---
-- Step 3: Update the LowLevelDetection column
-- This will be very fast now (only ~600 rows to update)
-- ---
UPDATE InventorySnapshot i
JOIN ProductROPandTurnover p
  ON i.ProductID = p.ProductID
  AND i.unique_storeid = p.unique_storeid
SET i.LowLevelDetection = 
    CASE 
        WHEN i.InventoryLevel < p.ReorderPoint THEN 'Yes'
        ELSE 'No'
    END;


-- SUMMARY OF KPI's AVERAGE INVENTORY, STOCKOUT RATE AND INVENTORY AGE 
CREATE TABLE kpi AS
WITH DailyData AS (
    -- 1. Get all daily metrics in one place
    SELECT
        i.Date,
        i.ProductID,
        i.unique_storeid,
        i.InventoryLevel,
        s.DemandForecast,
        s.UnitsSold,
        ph.Price,
        
        -- Flag for stockout (inventory < forecast)
        (CASE WHEN i.InventoryLevel < s.DemandForecast THEN 1 ELSE 0 END) AS is_at_risk,
        
        -- Calculate Daily COGS (assuming Price is Unit Cost)
        (s.UnitsSold * ph.Price) AS DailyCOGS,
        
        -- Calculate Inventory Value
        (i.InventoryLevel * ph.Price) AS InventoryValue
    FROM
        InventorySnapshot i
    -- Join Sales to get DemandForecast and UnitsSold
    JOIN 
        Sales s ON i.ProductID = s.ProductID 
               AND i.unique_storeid = s.unique_storeid 
               AND i.Date = s.Date
    -- Join PriceHistory to get Price (for monetary value)
    JOIN
        PriceHistory ph ON i.ProductID = ph.ProductID 
                       AND i.unique_storeid = ph.unique_storeid 
                       AND i.Date = ph.Date
),
-- 2. Aggregate the daily data
Aggregates AS (
    SELECT
        ProductID,
        unique_storeid,
        -- Calculate average inventory value
        AVG(InventoryValue) AS AvgInventoryValue,
        -- Calculate average daily COGS
        AVG(DailyCOGS) AS AvgDailyCOGS,
        -- Calculate average stockout risk
        AVG(is_at_risk) AS AvgStockoutRisk
    FROM
        DailyData
    GROUP BY
        ProductID, unique_storeid
)
-- 3. Calculate the final KPIs
SELECT
    ProductID,
    unique_storeid,
    
    -- This is your forecast-based stockout rate
    ROUND(AvgStockoutRisk * 100.0, 2) AS StockoutRate,
    
    -- This is the correct Average Inventory Age (DSI)
    CASE
        WHEN AvgDailyCOGS > 0 THEN ROUND(AvgInventoryValue / AvgDailyCOGS, 2)
        ELSE 0 -- Avoid division-by-zero if an item never sold
    END AS AverageInventoryAge_Days,

    -- This is the average value ($) of inventory on hand
    ROUND(AvgInventoryValue, 2) AS AvgInventoryValue

FROM
    Aggregates
ORDER BY 
    StockoutRate DESC, AverageInventoryAge_Days DESC;

    
  -- Required table for Supplier Performance dashboard 
CREATE TABLE SupplierPerformance AS 
  WITH InventoryWithLag AS (
    SELECT 
        ProductID,
        unique_storeid,
        Date,
        InventoryLevel,
        LAG(InventoryLevel) OVER (
            PARTITION BY ProductID, unique_storeid ORDER BY Date
        ) AS PrevInventoryLevel,
        LAG(Date) OVER (
            PARTITION BY ProductID, unique_storeid ORDER BY Date
        ) AS PrevDate
    FROM InventorySnapshot
),
Replenishments AS (
    SELECT 
        ProductID,
        unique_storeid,
        Date AS ReplenishmentDate,
        PrevDate,
        DATEDIFF(Date, PrevDate) AS DeliveryLag
    FROM InventoryWithLag
    WHERE 
        InventoryLevel > PrevInventoryLevel
        AND PrevDate IS NOT NULL
)
SELECT 
    r.ProductID,
    r.unique_storeid,
    r.ReplenishmentDate,
    r.DeliveryLag,
    p.Category,
    p.LeadTimeDays,
    CASE 
        WHEN r.DeliveryLag <= p.LeadTimeDays THEN 'Yes'
        ELSE 'No'
    END AS OnTimeFlag
FROM Replenishments r
JOIN product p
    ON r.ProductID = p.ProductID;
    




    















