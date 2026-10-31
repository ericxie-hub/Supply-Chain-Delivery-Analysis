use dataco;
-- Q1. Which shipping mode is late most often, and by how many days?
select shipping_mode, 
       count(*) as total_orders, 
       round(sum(case when delivery_status = 'Late Delivery' then 1 else 0 end) * 100.00 / count(*), 1) as late_delivery_pct,
       round(avg(days_shipping_real - days_shipping_scheduled), 2) as avg_days_late
from orders
group by shipping_mode;

select shipping_mode,
       days_shipping_scheduled,
       min(days_shipping_real) as min_actual,
       max(days_shipping_real) as max_actual
from orders
group by shipping_mode, days_shipping_scheduled;

select delivery_status, count(*)
from orders
where shipping_mode = 'First Class'
group by delivery_status;

/* 
Question 1 Findings
Answer: First Class is the shipping mode that is late most often by an average of 1 day late.
Evidence: 95.3% of First Class orders were late. Every First Class order took over 2 days to deliver, compared with the 1-day promise. 
The remaining 4.7% were from canceled orders. 
Why it matters: This is a major issue concerning the promises of a one day delivery that can't be ever be matched which would hurt customer
trust as we are providing a timetable that cannot be met even though they are paying premium for the service.
Recommendation: To resolve this issue, we would have to change our promise of 1 day to 2 days so that we would be able to deliver
on our established schedule. For Second Class, the delivery days range from 2 to 6 days and currently 76.7% of them were late.
The next step would be to find the causes for the variation in days before we can establish a new delivery window.
*/

-- Q2. Which markets and regions have the worst on-time rates?

select market,
       count(*) as total_deliveries,
       round(sum(case when delivery_status = 'Late delivery' then 1 else 0 end) * 100.00 / count(*),2) as late_pct
from orders
group by market;

select market, 
       order_region,
       count(*) as total_deliveries,
       round(sum(case when delivery_status = 'Late delivery' then 1 else 0 end) * 100.00 / count(*),2) as late_pct
from orders
group by market, order_region
having count(*) >= 100
order by late_pct desc;

select market, 
       order_region,
       shipping_mode,
       count(*) as total_deliveries,
       round(sum(case when delivery_status = 'Late delivery' then 1 else 0 end) * 100.00 / count(*),2) as late_pct
from orders
where shipping_mode = 'Second Class'
group by market, order_region, shipping_mode
having count(*) >= 100
order by late_pct desc;

/*
Question 2 Findings
Answer: All five markets have nearly identical late rates between 54% and 55%. Location isn't a driver for late deliveries.
Evidence: All five markets had late rates between 54.1% and 55.3%. 
Across the 23 regions with at least 100 orders, late rates ranged from only 49.51% to 57.6%. 
Although 49.51% is a lower rate, Canada has a low amount of total deliveries.
Why this matters: Finding out that location isn't a factor causing late deliveries, we can shift our focus to the different
shipping modes that is leading to late deliveries.
Recommendation: Fix late deliveries company-wide by shipping mode instead of by region. 
Reset the current First Class promise to a realistic window and review the Second Class delivery process.
This includes carriers used since late deliveries are sitting around 75%.
*/

-- Q3. Do late orders make less money compared to on-time orders?

select o.delivery_status,
       count(distinct oi.order_id) as total_orders, 
       round(sum(oi.profit),2) as total_profit,
       round(sum(oi.profit) / count(distinct oi.order_id), 2) as profit_per_order, 
       round(100.00 * sum(oi.profit) / sum(oi.net_sales),2) as profit_margin
from order_items oi
join orders o on oi.order_id = o.order_id
group by o.delivery_status
order by profit_per_order desc;

/*
Question 3 Findings
Answer: Late deliveries cost little in direct margin.
Evidence: Late deliveries have a profit per order of $59.37 with a 11.83% profit margin compared to on time deliveries with a $62.37 profit
per order and a 12.38% profit margin. That is about $3 less per late order, which results in roughly $108,000 lower profit overall.
Why this matters: Although the profit difference for late deliveries is small, the majority of late deliveries come from premium shipping services 
like First and Second Class so part of the profit gap may come from shipping mode rather than lateness. 
With customers using premium services and having late deliveries, customer trust can be lost throughout the process leading to them 
not using the service for future orders.
Recommendations: In order to protect customer trust, this leads back to resolving the issue related to First Class promise and review
Second Class process. If we are able to find a way to deliver on the set promises, customers would feel more inclined to continue using
our services. As a next step, we can compare repeat order rates for customers whose orders arrived late versus on time. This will 
allow us to measure if tardiness affects customer retention. 
*/

-- Q4: Do bigger discounts hurt profit, and which product categories lose money?

select case 
       when discount_rate < 0.05 then '0-5%'
       when discount_rate < 0.10 then '5-10%'
       when discount_rate < 0.15 then '10-15%'
       else '15%+' end as discount_band,
       count(*) as total_items,
       round(sum(profit),2) as total_profit,
       round(100.00 * sum(profit) / sum(net_sales), 2) as profit_margin
from order_items
group by  discount_band
order by min(discount_band);

select p.category_name, 
       case when discount_rate < 0.05 then '0-5%'
       when discount_rate < 0.10 then '5-10%'
       when discount_rate < 0.15 then '10-15%'
       else '15%+' end as discount_band,
       count(*) as total_items,
       round(sum(profit),2) as total_profit,
       round(100.00 * sum(profit) / sum(net_sales), 2) as profit_margin
from order_items oi
join products p on oi.product_id = p.product_id
group by p.category_name, discount_band
having count(*) >= 100
order by total_profit;

select p.category_name, 
       count(*) as total_items,
       round(sum(profit),2) as total_profit,
       round(100.00 * sum(profit) / sum(net_sales), 2) as profit_margin
from order_items oi
join products p on oi.product_id = p.product_id
group by p.category_name
having count(*) >= 100
order by profit_margin;
/*
Question 4 Findings
Answer: Bigger discounts do not hurt profit margin and no product category loses money overall. However, a few categories,
especially Strength Training (0.68%) barely break even.
Evidence: All discount rates have a profit margin between 11.78% and 12.36%. There is no significant difference that suggests discounts
hurt profit. No categories lost money overall. The only loss was DVDs at 5-10% discounts that lost $687, but DVDs
were still profitable overall.
Why this matters: Since discounts don’t reduce margins, the company can use promotions to drive sales volume without losing profitability. 
The real profit risk is low-margin categories like Strength Training, which generate sales but contribute almost nothing to profit.
Recommendations: Review pricing and costs for the lowest-margin categories, starting with Strength Training (0.68%). 
The fix might be raising prices, lowering supplier costs, or promoting these products less.
 As a next step, compare margins by individual product within these categories to find which items are pulling margins down.
 Note: Flat margins acorss discount levels are unusual in real retail data, so this may reflect how profit is calculated in this dataset.
*/

-- Q5: How have order volume and on-time rate trended month by month?

select DATE_FORMAT(order_date, '%Y-%m') as month,
       count(*) as total_orders,
       round(sum(case when delivery_status = 'Late delivery' then 1 else 0 end) * 100.00 / count(*), 2) as late_pct
from orders
group by month
order by month;

select p.category_name,
       count(distinct case when date_format(order_date, '%Y-%m') = '2017-09' then o.order_id end) as sep_orders,
       count(distinct case when date_format(order_date, '%Y-%m') = '2017-10' then o.order_id end) as oct_orders
from order_items oi
join orders o on oi.order_id = o.order_id
join products p on oi.product_id = p.product_id
where o.order_date >= '2017-09-01' and o.order_date < '2017-11-01'
group by p.category_name
order by oct_orders - sep_orders desc;

/*
Question 5 Findings
Answer: Order volume has roughly stayed consistent until October 2017, where order volume saw an increase of about 20%. 
Evidence: In October, 7 new categories were added to the catalog and saw an increase in volume due to these new additions, while some previous
items from September saw a drastic decrease in purchase volume such as Cleats that dropped from 616 orders to 30. The late rate
staying between 53-56%.
Why this matters: Even after the product lineup changed and volume rose about 20%, the late rate stayed around 55%. This evidence
suggests that late deliveries are caused by how the shipping modes are set up and not by what is being sold or how much. 
Recommendations: The shipping fixes from Q1 apply across the business regardless of product lineup. 
As a next step, check whether the new categories, like Cameras and Computers, are ordered with premium shipping more often. 
If so, the First and Second Class problems would affect them even more. The new categories' margins should also be monitored, 
since some, like Books, run below average.
Note: The product shift occurred suddenly in one month only in 2017, so it may reflect a business decision or how this dataset was built.
A seasonal effect was ruled out as no sudden increase occurred in October 2015 and 2016.
*/