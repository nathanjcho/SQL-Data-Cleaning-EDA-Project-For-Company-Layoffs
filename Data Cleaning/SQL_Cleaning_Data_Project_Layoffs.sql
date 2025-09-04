USE world_layoffs;

-- Data Cleaning --

#Look into raw data
SELECT * FROM layoffs_raw;

#Create a new table to perform cleaning on
CREATE TABLE layoffs_staging
LIKE layoffs_raw;

#Insert all the data from the original table to the new one
INSERT layoffs_staging
SELECT *
FROM layoffs_raw;

SELECT * FROM layoffs_staging;

#Remove the top row
DELETE FROM layoffs_staging
WHERE layoffs_staging.company = 'company'
LIMIT 1;

SELECT * FROM layoffs_staging;

#Identify all the duplicate entries
WITH dupe_cte AS (SELECT *,
       ROW_NUMBER() OVER (PARTITION BY company, location, industry, total_laid_off, percentage_laid_off,
       date, stage, country, funds_raised_millions) AS row_num
FROM layoffs_staging)
SELECT *
FROM dupe_cte
WHERE row_num  > 1;

#Proof of duplicate entries
SELECT * FROM layoffs_staging
WHERE company = 'Casper';

#Create a new table for deleting the duplicate entries
CREATE TABLE layoffs_staging2
LIKE layoffs_raw;

#Add the new row_num column
ALTER TABLE layoffs_staging2
ADD COLUMN row_num INT;

SELECT * FROM layoffs_staging2;

#Insert the data from the second table
INSERT INTO layoffs_staging2
SELECT *,
    ROW_NUMBER() OVER (PARTITION BY company, location, industry, total_laid_off, percentage_laid_off,
    'date', stage, country, funds_raised_millions) AS row_num
FROM layoffs_staging;

SELECT * FROM layoffs_staging2;

#Delete all duplicates
DELETE
FROM layoffs_staging2
WHERE row_num > 1;

-- Standardizing Data --

#Removes the spaces in company column
UPDATE layoffs_staging2
SET company = TRIM(company);

#View all distinct entries to standardize industries
SELECT DISTINCT (industry)
FROM layoffs_staging2
ORDER BY 1;

#Standardize all Crypto industries
UPDATE layoffs_staging2
SET industry = 'Crypto'
WHERE industry LIKE 'Crypto%';

#Check all distinct location entries
SELECT DISTINCT (location)
FROM layoffs_staging2
ORDER BY 1;

#Check all distinct country entries
SELECT DISTINCT (country)
FROM layoffs_staging2
ORDER BY 1;

#Remove '.' from 'United States.' entries
UPDATE layoffs_staging2
SET country = TRIM(TRAILING '.' FROM country)
WHERE country LIKE 'United States%';

#Change all date 'NULL' entries to <null> type
UPDATE layoffs_staging2
SET date = NULL
WHERE date = 'NULL';

#Change all date entries to date format
UPDATE layoffs_staging2
SET date = STR_TO_DATE(date, '%m/%d/%Y')
WHERE date IS NOT NULL;

#Change date column type from string to date
ALTER TABLE layoffs_staging2
MODIFY COLUMN date DATE;

#Change all other instances of 'NULL' to <null> value
UPDATE layoffs_staging2
SET
  company = NULLIF(company, 'NULL'),
  location = NULLIF(location, 'NULL'),
  industry = NULLIF(industry, 'NULL'),
  total_laid_off = NULLIF(total_laid_off, 'NULL'),
  percentage_laid_off = NULLIF(percentage_laid_off, 'NULL'),
  stage = NULLIF(stage, 'NULL'),
  country = NULLIF(country, 'NULL'),
  funds_raised_millions = NULLIF(funds_raised_millions, 'NULL')
WHERE
  company = 'NULL' OR
  location = 'NULL' OR
  industry = 'NULL' OR
  total_laid_off = 'NULL' OR
  percentage_laid_off = 'NULL' OR
  stage = 'NULL' OR
  country = 'NULL' OR
  funds_raised_millions = 'NULL';

#See all null industry values
SELECT *
FROM layoffs_staging2
WHERE industry IS NULL;

#Identify which companies have null values in industry that can be replaced
SELECT *
FROM layoffs_staging2 t1
JOIN layoffs_staging2 t2
    ON t1.company = t2.company
    AND t1.location = t2.location
WHERE t1.industry IS NULL
AND t2.industry IS NOT NULL;

#Update null values to existing industry values of the companies
UPDATE layoffs_staging2 t1
JOIN layoffs_staging2 t2
     ON t1.company = t2.company
     AND t1.location = t2.location
SET t1.industry = t2.industry
WHERE t1.industry IS NULL
AND t2.industry IS NOT NULL;

#Create a new table to delete all total_laid_off and percentage_laid_off entries that are both null
CREATE TABLE layoffs_staging3
LIKE layoffs_staging2;

SELECT *
FROM layoffs_staging3;

#Insert the data from layoffs_staging2 to layoffs_staging3
INSERT INTO layoffs_staging3
SELECT *
FROM layoffs_staging2;

SELECT *
FROM layoffs_staging3;

#Delete all total_laid_off and percentage_laid_off entries that are both null
DELETE
FROM layoffs_staging3
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL;

SELECT *
FROM layoffs_staging3;

#Drop row_num column
ALTER TABLE layoffs_staging3
DROP COLUMN row_num;

#Change date column type from string to date
ALTER TABLE layoffs_staging3
MODIFY COLUMN total_laid_off INT,
MODIFY COLUMN funds_raised_millions INT;

SELECT *
FROM layoffs_staging3;