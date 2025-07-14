CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
	DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME;
	--silver.crm_cust_info
	BEGIN TRY
		SET @batch_start_time = GETDATE();
        PRINT '================================================';
        PRINT 'Loading Silver Layer';
        PRINT '================================================';

		PRINT '------------------------------------------------';
		PRINT 'Loading CRM Tables';
		PRINT '------------------------------------------------';

		SET @start_time = GETDATE();
		PRINT'>> Truncating Table: silver.crm_cust_info';
		TRUNCATE TABLE silver.crm_cust_info;
		PRINT'>> Inserting Data Into: silver.crm_cust_info';
		INSERT INTO 
			silver.crm_cust_info(
				cst_id,
				cst_key,
				cst_firstname,
				cst_lastname,
				cst_marital_status,
				cst_gender,
				cst_create_date
				)
		SELECT
			cst_id,
			cst_key,
			TRIM(cst_firstname) AS cst_firstname,
			TRIM(cst_lastname) AS cst_lastname,
			CASE
				WHEN cst_marital_status = TRIM(UPPER('S')) THEN 'Single'
				WHEN cst_gender = TRIM(UPPER('M')) THEN 'Married'
				ELSE 'N/A'
			END AS cst_marital_status,
			CASE
				WHEN cst_gender = TRIM(UPPER('M')) THEN 'Male'
				WHEN cst_gender = TRIM(UPPER('F')) THEN 'Female'
				ELSE 'N/A'
			END AS cst_gender,
			cst_create_date
		FROM
			(SELECT
				*,
				ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last 
			FROM 
				bronze.crm_cust_info
			WHERE 
				cst_id IS NOT NULL
				)t
		WHERE
			flag_last = 1;
		SET @end_time = GETDATE();
		PRINT'Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time)AS NVARCHAR);
		PRINT'>> ----------';

		-- silver.crm_prd_info
		SET @start_time = GETDATE();
		PRINT'>> Truncating Table: silver.crm_prd_info';
		TRUNCATE TABLE silver.crm_prd_info;
		PRINT'>> Inserting Data Into: silver.crm_prd_info';
		INSERT INTO
			silver.crm_prd_info(
				prd_id,
				cat_id,
				prd_key,
				prd_nm,
				prd_cost,
				prd_line,
				prd_start_dt,
				prd_end_dt
			)
		SELECT
			prd_id,
			REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,
			SUBSTRING(prd_key, 7, LEN(prd_key)) AS prd_key,
			prd_nm,
			ISNULL(prd_cost, 0),
			CASE UPPER(TRIM(prd_line))
				WHEN 'R' THEN 'Road'
				WHEN 'S' THEN 'Other Sales'
				WHEN 'M' THEN 'Mountain'
				WHEN 'T' THEN 'Touring'
				ELSE 'N/A'
			END AS prd_line,
			prd_start_dt,
			DATEADD(DAY, -1, LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt)) AS prd_end_dt
		FROM
			bronze.crm_prd_info
		SET @end_time = GETDATE();
		PRINT'Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time)AS NVARCHAR);
		PRINT'>> ----------'

		-- silver.crm_sales_details
		SET @start_time = GETDATE();
		PRINT'>> Truncating Table: silver.crm_sales_details';
		TRUNCATE TABLE silver.crm_sales_details;
		PRINT'>> Inserting Data Into: silver.crm_sales_details';
		INSERT INTO silver.crm_sales_details(
			sls_ord_num,
			sls_prd_key,
			sls_cust_id,
			sls_order_dt,
			sls_ship_dt,
			sls_due_dt,
			sls_sales,
			sls_quantity,
			sls_price
			)
		SELECT
			sls_ord_num,
			sls_prd_key,
			sls_cust_id,
			CASE
				WHEN sls_order_dt = 0 OR LEN(sls_order_dt) != 8 THEN NULL
				ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE) 
			END AS sls_order_dt,
			CASE
				WHEN sls_ship_dt = 0 OR LEN(sls_ship_dt) != 8 THEN NULL
				ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE) 
			END AS sls_ship_dt,
			CASE
				WHEN sls_due_dt = 0 OR LEN(sls_due_dt) != 8 THEN NULL
				ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE) 
			END AS sls_due_dt,
			CASE 
				WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price) 
					THEN sls_quantity * ABS(sls_quantity)
				ELSE sls_sales 
			END AS sls_sales,
			sls_quantity,
			CASE
				WHEN sls_price IS NULL OR sls_price <= 0 THEN sls_sales/NULLIF(sls_quantity, 0)
				ELSE sls_price
			END AS sls_price
		FROM
			bronze.crm_sales_details;
		SET @end_time = GETDATE();
		PRINT'Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time)AS NVARCHAR);
		PRINT'>> ----------';


		PRINT '------------------------------------------------';
		PRINT 'Loading ERP Tables';
		PRINT '------------------------------------------------';

		-- silver.erp_cust_az12
		SET @start_time = GETDATE();
		PRINT'>> Truncating Table: silver.erp_cust_az12';
		TRUNCATE TABLE silver.erp_cust_az12;
		PRINT'>> Inserting Data Into: silver.erp_cust_az12';
		INSERT INTO 
			silver.erp_cust_az12(
				cid,
				bdate,
				gen
			)
		SELECT
			CASE	
				WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
				ELSE cid
			END AS cid,
			CASE 
				WHEN bdate > GETDATE() THEN NULL
				ELSE bdate
			END AS bdate,
			CASE 
				WHEN TRIM(UPPER(gen)) IN ('F', 'Female') THEN 'Female'
				WHEN TRIM(UPPER(gen)) IN ('M', 'Male') THEN 'Male'
				ELSE 'N/A'
			END AS gen
		FROM
			bronze.erp_cust_az12;
		SET @end_time = GETDATE();
		PRINT'Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time)AS NVARCHAR);
		PRINT'>> ----------'

		-- silver.erp_loc_a101
		SET @start_time = GETDATE();
		PRINT'>> Truncating Table: silver.erp_loc_a101';
		TRUNCATE TABLE silver.erp_loc_a101;
		PRINT'>> Inserting Data Into: silver.erp_loc_a101';
		INSERT INTO 
			silver.erp_loc_a101(
				cid,
				cntry
			)
		SELECT 
			REPLACE(cid, '-', '') AS cid,
			CASE 
				WHEN TRIM(cntry) = 'DE' THEN 'Germany'
				WHEN TRIM(cntry) IN ('US', 'USA') THEN 'United States'
				WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'N/A'
				ELSE cntry
			END AS cntry
		FROM	
			bronze.erp_loc_a101;
		SET @end_time = GETDATE();
		PRINT'Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time)AS NVARCHAR);
		PRINT'>> ----------';

		-- silver.erp_px_catg1v2
		SET @start_time = GETDATE();
		PRINT'>> Truncating Table: silver.erp_px_catg1v2';
		TRUNCATE TABLE silver.erp_px_catg1v2;
		PRINT'>> Inserting Data Into: silver.erp_px_catg1v2';
		INSERT INTO 
			silver.erp_px_catg1v2(
				id,
				cat,
				subcat,
				maintenence
			)
		SELECT 
			id,
			cat,
			subcat,
			maintenence
		FROM	
			bronze.erp_px_catg1v2;
		SET @end_time = GETDATE();
		PRINT'Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time)AS NVARCHAR);
		PRINT'>> ----------';

		SET @batch_end_time = GETDATE();
		PRINT '=========================================='
		PRINT 'Loading Silver Layer is Completed';
        PRINT '   - Total Load Duration: ' + CAST(DATEDIFF(SECOND, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
		PRINT '==========================================';
	END TRY
	BEGIN CATCH
		PRINT '=========================================='
		PRINT 'ERROR OCCURED DURING LOADING BRONZE LAYER'
		PRINT 'Error Message' + ERROR_MESSAGE();
		PRINT 'Error Message' + CAST (ERROR_NUMBER() AS NVARCHAR);
		PRINT 'Error Message' + CAST (ERROR_STATE() AS NVARCHAR);
		PRINT '=========================================='
	END CATCH
END