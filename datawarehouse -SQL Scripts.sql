select extract( year from order_date)as order_year,
sum(sales_amount) as total_sales,
count(quantity) as total_quantity,
count (distinct customer_key) as total_customers
from fact_sales 
group by  extract( year from order_date);

select 
order_month,
    total_sales,
    total_quantity,
    total_customers
	from (
SELECT 
    TO_CHAR(order_date, 'Mon') AS order_month,
    EXTRACT(MONTH FROM order_date) AS month_number,
    SUM(sales_amount) AS total_sales,
    COUNT(quantity) AS total_quantity,
    COUNT(distinct customer_key) AS total_customers
FROM fact_sales
GROUP BY TO_CHAR(order_date, 'Mon'), EXTRACT(MONTH FROM order_date) )
AS monthly_data
ORDER BY month_number;



SELECT
  DATE_TRUNC('year', order_date)::DATE AS order_month,
  SUM(sales_amount) AS monthly_sales,
  SUM(SUM(sales_amount)) OVER (ORDER BY DATE_TRUNC('year', order_date)) AS running_total
FROM fact_sales
GROUP BY DATE_TRUNC('year', order_date)
ORDER BY order_month;

WITH sales_by_product_year AS (
  SELECT 
    EXTRACT(YEAR FROM f.order_date) AS order_year,
    d.product_name,
    SUM(f.sales_amount) AS current_sales
  FROM fact_sales f 
  LEFT JOIN dim_products d ON f.product_key = d.product_key 
  GROUP BY EXTRACT(YEAR FROM f.order_date), d.product_name
)

SELECT 
  order_year,
  product_name,
  current_sales,
  round (AVG(current_sales) OVER (PARTITION BY product_name)) AS avg_sales,
  current_sales - round(avg(current_sales) OVER (PARTITION BY product_name)) AS diif_avg,
case when current_sales - round(avg(current_sales) OVER (PARTITION BY product_name)) >0 then 'Above avg'
when current_sales - round(avg(current_sales) OVER (PARTITION BY product_name)) <0 then 'Below avg '
else 'Avg'
end as avg_change, 
LAG(current_sales) OVER (PARTITION BY product_name order by order_year ) AS previous_year_sales,
current_sales - LAG(current_sales) OVER (PARTITION BY product_name ) AS sales_diff,
case when current_sales - lag(current_sales) OVER (PARTITION BY product_name)>0 then'increase'
when current_sales - lag(current_sales) OVER (PARTITION BY product_name) <0 then'decrease'
else 'no change'
end as productyear_change
FROM sales_by_product_year
ORDER BY product_name, order_year desc;

with category_sales as (
select category,sum(sales_amount)as total_sales
from fact_sales f 
left join dim_products d
on d.product_key=f.product_key
group by 1)
select category,total_sales,
sum(total_sales) over() overall_sales,
round((total_sales/sum(total_sales) over())*100,2) as percentage_of_total
from category_sales;

WITH customer_spending AS (
  SELECT 
    c.customer_key,
    SUM(f.sales_amount) AS total_spending,
    MIN(order_date) AS first_order,
    MAX(order_date) AS last_order,
    EXTRACT(YEAR FROM AGE(MAX(f.order_date), MIN(f.order_date))) * 12 +
    EXTRACT(MONTH FROM AGE(MAX(f.order_date), MIN(f.order_date))) AS lifespan
  FROM fact_sales f
  LEFT JOIN dim_customers c 
    ON f.customer_key = c.customer_key
  GROUP BY c.customer_key
)

SELECT 
  CASE 
    WHEN lifespan >= 12 AND total_spending > 5000 THEN 'VIP'
    WHEN lifespan >= 12 AND total_spending BETWEEN 2000 AND 5000 THEN 'Loyal'
    WHEN lifespan < 12 AND total_spending BETWEEN 2000 AND 5000 THEN 'Regular'
    ELSE 'New'
  END AS customer_segment,
  COUNT(*) AS segment_count

FROM customer_spending
GROUP BY customer_segment
ORDER BY segment_count DESC;




