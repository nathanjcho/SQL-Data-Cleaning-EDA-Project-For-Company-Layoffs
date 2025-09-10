-- Exploratory Data Analysis --

-- 1. Overview --
USE world_layoffs;

SELECT *
FROM layoffs_staging3;

#Find the entire timeline (3/11/20 - 3/6/23)
SELECT MIN(date), MAX(date)
FROM layoffs_staging3;

-- 2. Descriptive Statistics --

#Max number of people (12000) and max percentage of people (100%) laid off
SELECT MAX(total_laid_off), MAX(percentage_laid_off)
FROM layoffs_staging3;

#Companies that laid off 100% of employees, ordered by total layoffs (2434)
SELECT *
FROM layoffs_staging3
WHERE percentage_laid_off = 1
ORDER BY total_laid_off DESC;

#Companies that laid off 100% of employees, ordered by funds raised (2400 M)
SELECT *
FROM layoffs_staging3
WHERE percentage_laid_off = 1
ORDER BY funds_raised_millions DESC;

-- 3. Company and Industry Insights --

#Assess companies by the most layoffs, highest average, and number of layoffs
SELECT company, SUM(total_laid_off) as sum_total, ROUND(AVG(total_laid_off),2) AS avg_size, COUNT(*) AS num_events
FROM layoffs_staging3
GROUP BY company
ORDER BY sum_total DESC;

#Top 3 companies for each category
WITH company_stats AS (
    SELECT company,
           SUM(total_laid_off) AS sum_total,
           ROUND(AVG(total_laid_off),2) AS avg_size,
           COUNT(*) AS num_events
    FROM layoffs_staging3
    GROUP BY company
)
SELECT 'Most Total Layoffs' AS category, company, metric
FROM (
    SELECT company, sum_total AS metric
    FROM company_stats
    ORDER BY sum_total DESC
    LIMIT 3
) AS total_layoffs

UNION ALL

SELECT 'Highest Average Layoff', company, metric
FROM (
    SELECT company, avg_size AS metric
    FROM company_stats
    ORDER BY avg_size DESC
    LIMIT 3
) AS avg_layoffs

UNION ALL

SELECT 'Most Layoff Events', company, metric
FROM (
    SELECT company, num_events AS metric
    FROM company_stats
    ORDER BY num_events DESC
    LIMIT 3
) AS layoff_count;

#Assess industries by the most layoffs, highest average, and number of layoffs
SELECT industry, SUM(total_laid_off) as sum_total, ROUND(AVG(total_laid_off),2) AS avg_size, COUNT(*) as num_events
FROM layoffs_staging3
WHERE industry IS NOT NULL
GROUP BY industry
ORDER BY 2 DESC;

#Top 3 industries for each category
WITH industry_stats AS (
    SELECT industry,
           SUM(total_laid_off) AS sum_total,
           ROUND(AVG(total_laid_off),2) AS avg_size,
           COUNT(*) AS num_events
    FROM layoffs_staging3
    GROUP BY industry
)
SELECT 'Most Total Layoffs' AS category, industry, metric
FROM (
    SELECT industry, sum_total AS metric
    FROM industry_stats
    ORDER BY sum_total DESC
    LIMIT 3
) AS total_layoffs

UNION ALL

SELECT 'Highest Average Layoff', industry, metric
FROM (
    SELECT industry, avg_size AS metric
    FROM industry_stats
    ORDER BY avg_size DESC
    LIMIT 3
) AS avg_layoffs

UNION ALL

SELECT 'Most Layoff Events', industry, metric
FROM (
    SELECT industry, num_events AS metric
    FROM industry_stats
    ORDER BY num_events DESC
    LIMIT 3
) AS layoff_count;

-- 4. Geographic Insights --

#Total layoffs and proportion of total layoffs per country
SELECT country, SUM(total_laid_off) AS sum_total,
       ROUND(SUM(total_laid_off) * 100.0 / (SELECT SUM(total_laid_off) FROM layoffs_staging3), 2) as pct_of_total
FROM layoffs_staging3
GROUP BY country
ORDER BY sum_total DESC;

#Top 5 countries with most layoffs per year
WITH country_year AS (
    SELECT YEAR(date) AS year, country, SUM(total_laid_off) AS sum_total
    FROM layoffs_staging3
    WHERE YEAR(date) IS NOT NULL
    GROUP BY YEAR(date), country
),
ranks AS (
SELECT *, DENSE_RANK() OVER (PARTITION BY year ORDER BY sum_total DESC) AS ranking
FROM country_year
ORDER BY year, ranking
)
SELECT *
FROM ranks
WHERE ranking <= 5;

#Total layoffs, proportion of country, and proportion of total per location
WITH totals AS (
    SELECT country, location, SUM(total_laid_off) AS sum_total
    FROM layoffs_staging3
    GROUP BY country, location
)
SELECT country, location, sum_total,
    ROUND(sum_total * 100.0 / SUM(sum_total) OVER (PARTITION BY country), 2) AS pct_of_country,
    ROUND(sum_total * 100.0 / (SELECT SUM(total_laid_off) FROM layoffs_staging3), 2) AS pct_of_total
FROM totals
ORDER BY sum_total DESC;

-- 5. Timeline Analysis --

#First and last layoff per company (0 means only one layoff)
SELECT company, MIN(date) AS first_layoff, MAX(date) AS last_layoff,
       DATEDIFF(MAX(date), MIN(date)) AS duration
FROM layoffs_staging3
GROUP BY company
ORDER BY duration DESC;

#Total layoffs per year (2023 only 3 months recorded)
SELECT YEAR(date), SUM(total_laid_off) as sum_total
FROM layoffs_staging3
GROUP BY 1
ORDER BY 1 DESC;

#Total layoffs per month
SELECT SUBSTR(date, 1, 7) AS month, SUM(total_laid_off) AS sum_total
FROM layoffs_staging3
WHERE SUBSTR(date, 1, 7) IS NOT NULL
GROUP BY 1
ORDER BY 2 DESC;

#Rolling total of layoffs per month
WITH rolling_total AS (
   SELECT SUBSTR(date, 1, 7) AS month, SUM(total_laid_off) AS sum_total
    FROM layoffs_staging3
    WHERE SUBSTR(date, 1, 7) IS NOT NULL
    GROUP BY 1
    ORDER BY 1
)
SELECT month, sum_total, SUM(sum_total) OVER (ORDER BY rolling_total.month) AS roll_total
FROM rolling_total;

#Total and average layoffs per quarter combined (with and without 2023 because of incomplete data)
SELECT
    QUARTER(date) AS quarter,
    SUM(total_laid_off) AS total_with_2023,
    AVG(total_laid_off) AS avg_with_2023,
    SUM(CASE WHEN YEAR(date) != 2023 THEN total_laid_off END) AS total_without_2023,
    AVG(CASE WHEN YEAR(date) != 2023 THEN total_laid_off END) AS avg_without_2023
FROM layoffs_staging3
WHERE QUARTER(date) IS NOT NULL
GROUP BY quarter
ORDER BY quarter;

-- 6. Rankings --

#Top 5 companies with most layoffs per year
WITH company_year AS (
    SELECT company, YEAR(date) AS years, SUM(total_laid_off) as sum_total
    FROM layoffs_staging3
    GROUP BY company, YEAR(date)
),
company_year_rank AS (
    SELECT *, DENSE_RANK () OVER (PARTITION BY years ORDER BY sum_total DESC) AS ranking
    FROM company_year
    WHERE years IS NOT NULL
)
SELECT *
FROM company_year_rank
WHERE ranking <= 5;

#Top 5 industries with most layoffs per year
WITH industry_year AS (
    SELECT industry, YEAR(date) AS years, SUM(total_laid_off) as sum_total
    FROM layoffs_staging3
    GROUP BY industry, YEAR(date)
),
industry_year_rank AS (
    SELECT *, DENSE_RANK () OVER (PARTITION BY years ORDER BY sum_total DESC) AS ranking
    FROM industry_year
    WHERE years IS NOT NULL
)
SELECT *
FROM industry_year_rank
WHERE ranking <= 5;

-- 7. Funding and Stage Analysis--

#Layoffs by company stage
SELECT stage, SUM(total_laid_off)
FROM layoffs_staging3
GROUP BY stage
ORDER BY 2 DESC;

#Correlation between funding and layoffs
SELECT company, funds_raised_millions, SUM(total_laid_off) AS sum_total
FROM layoffs_staging3
GROUP BY company, funds_raised_millions
ORDER BY funds_raised_millions DESC;

#Correlation between stage and industry
SELECT stage, industry, SUM(total_laid_off) AS sum_total
FROM layoffs_staging3
GROUP BY stage, industry
ORDER BY sum_total DESC;

