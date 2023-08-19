-- Viewing all tables one by one : 
SELECT *
FROM productsalesfact;

SELECT *
FROM customerdim;

SELECT *
FROM productcategory;

SELECT *
FROM productdim;

SELECT *
FROM complaints;

-- Section 1: 

-- Q1. Identifying the oldest customers in our database.

SELECT Customer_Id
	,C_Name
	,Customer_Since
FROM customerdim
ORDER BY Customer_Since LIMIT 5;

-- Q2. Identifying the top 5 customers having a lot of purchase activity on our platform and getting the customer names in asc order where it’s a tie.

SELECT psf.Customer_Id
	,C_Name
	,SUM(Amount_Paid) AS Total_Purchase
FROM productsalesfact psf
INNER JOIN customerdim cd ON psf.Customer_Id = cd.Customer_Id
GROUP BY psf.Customer_Id
	,C_Name
ORDER BY Total_Purchase DESC
	,C_Name LIMIT 5;

-- Q3.Identifying the customers with maximum purchase activity in different usage segments.

SELECT Cust_Usage
	,C_Name
	,COUNT(Amount_Paid) AS Purchase_Activity
FROM productsalesfact psf
INNER JOIN customerdim cd ON psf.Customer_Id = cd.Customer_Id
GROUP BY Cust_Usage
	,C_Name
HAVING Purchase_Activity = 2
ORDER BY Cust_Usage
	,Purchase_Activity DESC
	,C_Name;

/*
Based on above identified customers, creating strings for top customers having frequent purchase activity in different usage segment in format 
“Congratulations {Customer_Name}! You are eligible for a coupon of 75% off upto 5000 INR to be redeemed till {date}. You can find that in your email.” 
*/

SELECT CONCAT (
		'Congratulations '
		,C_Name
		,'! You are eligible for a coupon of 75% off upto 5000 INR to be redeemed till '
		,DATE_FORMAT(DATE_ADD(DATE (NOW()), INTERVAL 30 DAY), '%M %d %Y')
		,'. You can find that in your email.'
		) AS created_string
FROM (
	SELECT Cust_Usage
		,C_Name
		,COUNT(Amount_Paid) AS Purchase_Activity
	FROM productsalesfact psf
	INNER JOIN customerdim cd ON psf.Customer_Id = cd.Customer_Id
	GROUP BY Cust_Usage
		,C_Name
	HAVING Purchase_Activity = 2
	ORDER BY Cust_Usage
		,Purchase_Activity DESC
		,C_Name
	) T;

-- Section 2 : 
-- To limit the customers to certain product categories that they can spend their discount couponon, we have tried to identify the categories that they like.
-- Q1. No. of products that are 300 days older in our inventory by
-- a. Product category sorted by the total stock price.

SELECT pc.NAME
	,COUNT(*) Product_Count
	,SUM(Price) AS Stock_Price
FROM productdim pd
INNER JOIN productcategory pc ON pd.Category_Id = pc.Id
WHERE DATEDIFF(DATE (NOW()), In_Inventory) > 300
GROUP BY pc.NAME
ORDER BY Stock_Price DESC;

-- b. Product category with Return or Exchange type sorted by the total stock price.

SELECT pc.NAME
	,Return_Or_Exchange
	,COUNT(*) AS Product_Count
	,SUM(Price) AS Stock_Price
FROM productdim pd
INNER JOIN productcategory pc ON pd.Category_Id = pc.Id
WHERE DATEDIFF(DATE (NOW()), In_Inventory) > 300
GROUP BY pc.NAME
	,Return_Or_Exchange
ORDER BY Stock_Price DESC;

-- Q2. Identifying the product category which customers have bought a lot in each month in different usage segment ordered by their frequencies.
SELECT Month_Of_Purchase
	,Cust_Usage
	,NAME
	,COUNT(*) AS Purchase_Frequency
FROM (
	SELECT MONTH(DateofPurchase) AS Month_Of_Purchase
		,Cust_Usage
		,PC.NAME
	FROM productsalesfact psf
	INNER JOIN productdim pd ON psf.Product_Id = pd.Product_Id
	INNER JOIN productcategory pc ON pd.Category_Id = pc.Id
	) T
GROUP BY Month_Of_Purchase
	,Cust_Usage
	,NAME
ORDER BY Month_Of_Purchase
	,Cust_Usage
	,NAME
	,Purchase_Frequency DESC;

-- Section 3 : 
/*
Considering the scenario that we have quite a lot of complaints for different products in product categories. 
An organization can’t resolve all the queries at the same time so they try to prioritise the complaints received in highest volumes first. 
*/
-- Q1. Identifying the total number of complaints by
-- a. Product category along with query resolved or not

SELECT pc.NAME
	,Resolved
	,COUNT(*) AS Complaints_counts
FROM complaints c
INNER JOIN productsalesfact psf ON c.complaint_id = psf.complaint_id
INNER JOIN productdim pd ON psf.Product_Id = pd.Product_Id
INNER JOIN ProductCategory pc ON pd.Category_Id = pc.Id
GROUP BY pc.NAME
	,Resolved
ORDER BY Complaints_counts DESC;

-- b. Complaint_Name
SELECT Complaint_Name
	,COUNT(*) AS Complaints_Count
FROM complaints
GROUP BY Complaint_Name
ORDER BY Complaints_Count DESC;

-- 2. Identifying the fraction of complaints that are resolved by each product category vs fraction of complaints that aren’t resolved 
-- by each product category.

SELECT NAME
	,SUM(Flag) / COUNT(Flag) AS Fraction_resolved
	,1 - (SUM(Flag) / COUNT(Flag)) AS Fraction_not_resolved
FROM (
	SELECT pc.NAME
		,Resolved
		,CASE 
			WHEN Resolved = 'Resolved'
				THEN 1
			ELSE 0
			END AS Flag
	FROM complaints c
	INNER JOIN productsalesfact psf ON c.complaint_id = psf.complaint_id
	INNER JOIN productdim pd ON psf.Product_Id = pd.Product_Id
	INNER JOIN ProductCategory pc ON pd.Category_Id = pc.Id
	) T
GROUP BY NAME;

-- Section 4
-- Q1. Ranking the customers based on
-- a. Total purchasing they have done in terms of amount in descending order

SELECT row_number() OVER (
		ORDER BY Total_Purchase DESC
		) AS Purchase_Rank
	,C_Name
	,Total_Purchase
FROM (
	SELECT C_Name
		,sum(Amount_Paid) AS Total_Purchase
	FROM productsalesfact psf
	INNER JOIN customerdim cd ON psf.Customer_Id = cd.Customer_Id
	GROUP BY C_Name
	) T;

-- b. Total quantities they have purchased by descending order
SELECT row_number() OVER (
		ORDER BY Total_Quantity DESC
		) AS Purchase_Rank
	,C_Name
	,Total_Quantity
FROM (
	SELECT C_Name
		,sum(Quantity) AS Total_Quantity
	FROM productsalesfact psf
	INNER JOIN customerdim cd ON psf.Customer_Id = cd.Customer_Id
	GROUP BY C_Name
	) T;

-- Q2. Identifying the top 1 ranking product/s within each product category by their 
-- a. Price.

SELECT *
FROM (
	SELECT dense_rank() OVER (
			PARTITION BY Category_Name ORDER BY Price DESC
			) AS _Rank
		,Category_Name
		,Product_Name
		,Price
	FROM (
		SELECT pc.NAME AS Category_Name
			,pd.NAME AS Product_Name
			,Price
		FROM productsalesfact psf
		INNER JOIN productdim pd ON psf.Product_Id = pd.Product_Id
		INNER JOIN productcategory pc ON pd.Category_Id = pc.Id
		) T
	) T
WHERE _Rank = 1;

-- b. Number of days they are in inventory from current date.

SELECT *
FROM (
	SELECT dense_rank() OVER (
			PARTITION BY Category_Name ORDER BY Days_Elapsed DESC
			) AS _Rank
		,Category_Name
		,Product_Name
		,Days_Elapsed
	FROM (
		SELECT pc.NAME AS Category_Name
			,pd.NAME AS Product_Name
			,datediff(DATE (Now()), In_Inventory) AS Days_Elapsed
		FROM productdim pd
		INNER JOIN productcategory pc ON pd.Category_Id = pc.Id
		) T
	) T
WHERE _Rank = 1;

-- 3. Ranking the complaints that are not resolved by their number of days. Categorizing the results by the Complaint Name.

SELECT dense_rank() OVER (
		PARTITION BY Complaint_Name ORDER BY Days_Elapsed DESC
		) AS _Rank
	,Complaint_Name
	,Complaint_Id
	,Days_Elapsed
FROM (
	SELECT Complaint_Id
		,Complaint_Name
		,datediff(DATE (Now()), Complaint_Date) AS Days_Elapsed
	FROM complaints
	WHERE Resolved = "Not Resolved"
	) T;

-- Section 5
-- 1. Comparing the total purchase by amount that happened on a week by week basis. 

SELECT Total_Amount
	,Total_AMount_LastWeek
	,WeekofPurchase
	,Total_Amount - Total_Amount_LastWeek AS Change_In_Sales
FROM (
	SELECT WeekofPurchase
		,Total_Amount
		,Lag(Total_Amount) OVER () AS Total_Amount_LastWeek
	FROM (
		SELECT WeekofPurchase
			,sum(Amount_Paid) AS Total_Amount
		FROM (
			SELECT Amount_Paid
				,DateofPurchase
				,week(DateofPurchase) AS WeekofPurchase
			FROM productsalesfact
			) T
		GROUP BY WeekofPurchase
		ORDER BY WeekofPurchase
		) T
	) T;

-- 2. Comparing the number of customers that you witness week-by-week basis on your platform.

SELECT *
	,(Customer_Count - Customer_Count_lastWeek) AS Change_In_Customers
FROM (
	SELECT WeekofPurchase
		,Customer_Count
		,lag(Customer_Count) OVER () AS Customer_Count_Lastweek
	FROM (
		SELECT WeekofPurchase
			,count(*) AS Customer_Count
		FROM (
			SELECT *
				,week(DateofPurchase) AS WeekofPurchase
			FROM productsalesfact
			) T
		GROUP BY WeekofPurchase
		) T
	) T;

-- Section 6
/*
Q1. Dividing the household customer into 3 segments: highPurchase, mediumPurchase and lowPurchase based on ranking of customers by their total purchase amount 
(first 25% in low, 25 to 75 medium and > 75% high)
*/

SELECT *
	,CASE 
		WHEN _Rank > 75
			THEN "highPurchase"
		WHEN _Rank BETWEEN 25
				AND 75
			THEN "mediumPurchase"
		ELSE "lowPurchase"
		END AS Purchase_Segment
FROM (
	SELECT *
		,(
			percent_rank() OVER (
				ORDER BY Total_Purchase DESC
				)
			) * 100 AS _Rank
	FROM (
		SELECT Customer_Id
			,Sum(Amount_Paid) AS Total_Purchase
		FROM productsalesfact
		WHERE Cust_Usage = "Household"
		GROUP BY Customer_Id
		) T
	) T;

-- Calculating:
-- 1. Number of customers in each segment.

SELECT Purchase_Segment
	,count(*) AS Customers_Count
FROM (
	SELECT *
		,CASE 
			WHEN _Rank > 75
				THEN "highPurchase"
			WHEN _Rank BETWEEN 25
					AND 75
				THEN "mediumPurchase"
			ELSE "lowPurchase"
			END AS Purchase_Segment
	FROM (
		SELECT *
			,(
				percent_rank() OVER (
					ORDER BY Total_Purchase DESC
					)
				) * 100 AS _Rank
		FROM (
			SELECT Customer_Id
				,Sum(Amount_Paid) AS Total_Purchase
			FROM productsalesfact
			WHERE Cust_Usage = "Household"
			GROUP BY Customer_Id
			) T
		) T
	) T
GROUP BY Purchase_Segment;

-- 2. Total purchase within each segment in terms of
-- Quantity

SELECT Purchase_Segment
	,sum(Total_Quantity) AS Total_Quantity_In_Segment
FROM (
	SELECT *
		,CASE 
			WHEN _Rank > 75
				THEN "highPurchase"
			WHEN _Rank BETWEEN 25
					AND 75
				THEN "mediumPurchase"
			ELSE "lowPurchase"
			END AS Purchase_Segment
	FROM (
		SELECT *
			,(
				percent_rank() OVER (
					ORDER BY Total_Purchase DESC
					)
				) * 100 AS _Rank
		FROM (
			SELECT Customer_Id
				,Sum(Amount_Paid) AS Total_Purchase
				,Sum(Quantity) AS Total_Quantity
			FROM productsalesfact
			WHERE Cust_Usage = "Household"
			GROUP BY Customer_Id
			) T
		) T
	) T
GROUP BY Purchase_Segment;

-- Purchase amount
SELECT Purchase_Segment
	,sum(Total_Purchase) AS Purchase_in_Segment
FROM (
	SELECT *
		,CASE 
			WHEN _Rank > 75
				THEN "highPurchase"
			WHEN _Rank BETWEEN 25
					AND 75
				THEN "mediumPurchase"
			ELSE "lowPurchase"
			END AS Purchase_Segment
	FROM (
		SELECT *
			,(
				percent_rank() OVER (
					ORDER BY Total_Purchase DESC
					)
				) * 100 AS _Rank
		FROM (
			SELECT Customer_Id
				,Sum(Amount_Paid) AS Total_Purchase
			FROM productsalesfact
			WHERE Cust_Usage = "Household"
			GROUP BY Customer_Id
			) T
		) T
	) T
GROUP BY Purchase_Segment;

-- Q2. Sorting the household customers by the amount paid.

SELECT dense_rank() OVER (
		ORDER BY Total_Purchase DESC
		) AS _Rank
	,Customer_Id
	,Total_Purchase
FROM (
	SELECT Customer_Id
		,sum(Amount_Paid) AS Total_Purchase
	FROM productsalesfact
	GROUP BY Customer_Id
	) T;


-- Section 7: 

-- 1. Creating functions for the following:
-- 1. Getting the age of customer.

Delimiter //

CREATE FUNCTION Get_Age (DOB DATETIME)
RETURNS INT Deterministic

BEGIN
	DECLARE Years INT;

	SET Years = Year(now()) - Year(DOB);

	RETURN Years;
END //

Delimiter;

SELECT Get_Age(Birthdate)
FROM customerdim;

-- 2. Get the full address of a customer [ concatinating city, state, etc. to address]

Delimiter //

CREATE FUNCTION Full_Address_Func (
	Address VARCHAR(100)
	,City VARCHAR(20)
	,STATE VARCHAR(20)
	,Pincode VARCHAR(10)
	)
RETURNS VARCHAR(150) deterministic

BEGIN
	DECLARE Full_Address VARCHAR(150);

	SET Full_Address = concat_ws(", ", Address, City, STATE, Pincode);

	RETURN Full_Address;
END //

Delimiter;

SELECT Full_Address_Func(Address, City, STATE, Pincode) AS Address_
FROM customerdim;

-- Q2. Write Views using above functions:
/*
1. Identify the customers by different age group/segments - 10-19, 20-30, 30-60, >60 
and get the total amount offered they purchased in each segment.
*/

CREATE VIEW AgeGroupSales
AS
SELECT Cust_Usage
	,Age_Segment
	,SUM(Amount_Paid) AS Total_Amount
FROM (
	SELECT psf.Customer_Id
		,Amount_Paid
		,Cust_Usage
		,Birthdate
		,GET_AGE(Birthdate) AS Age
		,CASE 
			WHEN GET_AGE(Birthdate) BETWEEN 10
					AND 19
				THEN '10-19'
			WHEN GET_AGE(Birthdate) BETWEEN 20
					AND 30
				THEN '20-30'
			WHEN GET_AGE(Birthdate) BETWEEN 30
					AND 60
				THEN '30-60'
			WHEN GET_AGE(Birthdate) > 60
				THEN '>60'
			END AS Age_Segment
	FROM productsalesfact psf
	INNER JOIN customerdim cd ON psf.Customer_Id = cd.Customer_Id
	) T
GROUP BY Cust_Usage
	,Age_Segment
ORDER BY Cust_Usage;

SELECT *
FROM AgeGroupSales;
 
/*
2. Displaying message for bulk order item (quantity >= 10) - “Sorry, the order delivery to your {Full Address} is delayed by 2 days.  
Its expected to arrive on {date}” where date is 2 days from now.
*/

CREATE VIEW Bulk_Order_Message
AS
SELECT CONCAT (
		"“Sorry, the order delivery to your "
		,Full_Address_Func(Address, City, STATE, Pincode)
		," is delayed by 2 days. Its expected
to arrive on "
		,date_add(DATE (now()), interval 2 day)
		,"”"
		) AS Message
FROM productsalesfact psf
INNER JOIN customerdim cd ON psf.Customer_Id = cd.Customer_Id where Quantity > 10;


SELECT *
FROM Bulk_Order_Message;

/* 
Q3. Considering that we want to display different images by age groups if their order is late. 
Writing a stored procedure where for bulk order item (quantity >=10) have to an animation of ‘puppy’ for 10-19, ‘a warehouse person with loading box’
for 20-30, ‘a moving truck’ for 30-60 and a ‘puppy’ for >60 again [This will just be a column with Image type displayed].
Writing a stored procedure for the task given the Date of birth of customer.
*/

Delimiter //

CREATE PROCEDURE Display_Image (
	DOB DATETIME)

BEGIN
	SELECT CASE 
			WHEN Age_Segment = "10-19"
				THEN "Puppy"
			WHEN Age_Segment = "20-30"
				THEN "a warehouse person with loading box"
			WHEN Age_Segment = "30-60"
				THEN "a moving truck"
			WHEN Age_Segment = "10-19"
				THEN "Puppy"
			END AS D_Image
	INTO IMAGE
	FROM (
		SELECT C_Name
			,Quantity
			,Birthdate
			,Get_Age(Birthdate) AS Age
			,CASE 
				WHEN GET_AGE(Birthdate) BETWEEN 10
						AND 19
					THEN '10-19'
				WHEN GET_AGE(Birthdate) BETWEEN 20
						AND 30
					THEN '20-30'
				WHEN GET_AGE(Birthdate) BETWEEN 30
						AND 60
					THEN '30-60'
				WHEN GET_AGE(Birthdate) > 60
					THEN '>60'
				END AS Age_Segment
		FROM productsalesfact psf
		INNER JOIN customerdim cd ON psf.Customer_Id = cd.Customer_Id
		) T
	WHERE Birthdate = DOB;
END //

Delimiter;









