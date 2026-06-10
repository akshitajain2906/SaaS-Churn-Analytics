-- Section 1 - Subscription Health
-- a) Active vs Cancelled
select status, count(*) as total_subscriptions
from subscriptions
group by status;

-- b) Plan Distribution
select plan_type, count(*) as total_subscriptions
from subscriptions
group by plan_type;

-- c) True Active Subscriptions
-- status alone is not enough, some active records have an end_date in the past
-- reference date is pulled from the data so no hardcoding needed
with reference_date as (
select max(coalesce(end_date,start_date)) as report_date
from subscriptions)
select count(*) as true_active_subscriptions
from subscriptions s cross join reference_date r
where s.status = 'Active'
and s.start_date <= r.report_date
and (s.end_date is null or s.end_date >= r.report_date);


-- Section 2 - Financial Churn and Revenue Impact
-- a) Churned Customers
-- catches both explicitly cancelled and active records where end_date has already passed
-- distinct on customer_id so a customer with multiple churned rows only appears once
with reference_date as (
select max(coalesce(end_date,start_date)) as report_date
from subscriptions)
select distinct s.customer_id
from subscriptions s cross join reference_date r
where s.status = 'Canceled'
or (s.status = 'Active' and s.end_date is not null and s.end_date < r.report_date);

-- b) Churn Rate
-- churned subscriptions as a percentage of total
with reference_date as (
select max(coalesce(end_date,start_date)) as report_date
from subscriptions)
select round(
sum(case when s.status = 'Canceled'
or (s.status = 'Active' and s.end_date is not null and s.end_date < r.report_date)
then 1 else 0 end) / count(*) * 100, 2) as churn_rate_pct
from subscriptions s cross join reference_date r;

-- c) Revenue Lost from Churned Customers
-- separating the churned customer list into its own cte first
-- then filtering transactions directly to avoid fan-out from joining subscriptions
with reference_date as (
select max(coalesce(end_date,start_date)) as report_date
from subscriptions),
churned_customers as (
select distinct s.customer_id
from subscriptions s cross join reference_date r
where s.status = 'Canceled'
or (s.status = 'Active' and s.end_date is not null and s.end_date < r.report_date))
select round(sum(t.amount),2) as churned_revenue
from transactions t
where t.customer_id in (select customer_id from churned_customers);


-- Section 3 - Revenue
-- a) Total Revenue
select round(sum(amount),2) as total_revenue
from transactions;

-- b) Lifetime Revenue per Customer
-- ranked by highest spend to identify high value customers
select customer_id, round(sum(amount),2) as lifetime_revenue
from transactions
group by customer_id
order by lifetime_revenue desc;


-- Section 4 - Engagement
-- a) Last Login per Customer
select customer_id, max(event_date) as last_login_date
from user_activity
where event_type = 'Login'
group by customer_id;

-- b) Engagement Churn - Active Subscriptions Only
-- active subscribers with no login in 90+ days
-- is null catches customers who have never logged in at all
with reference_date as (
select max(event_date) as report_date
from user_activity)
select s.customer_id
from subscriptions s
left join user_activity ua
on s.customer_id = ua.customer_id
and ua.event_type = 'Login'
where s.status = 'Active'
group by s.customer_id
having max(ua.event_date) is null
or max(ua.event_date) < (select report_date from reference_date) - interval 90 day;


-- Section 5 - Silent Churn (Feature Usage)
-- a customer can log in without actually using the product
-- tracking feature usage separately catches that gap
with reference_date as (
select max(event_date) as report_date
from user_activity)
select s.customer_id
from subscriptions s
left join user_activity ua
on s.customer_id = ua.customer_id
and ua.event_type = 'Feature_Usage'
where s.status = 'Active'
group by s.customer_id
having max(ua.event_date) is null
or max(ua.event_date) < (select report_date from reference_date) - interval 90 day;


-- Section 6 - Final Customer Classification
-- every customer gets one label: Financial Churn, Engagement Risk, No Subscription, or Active
-- row_number picks each customer's most recent subscription row to avoid duplicate rows
-- two reference dates needed, one for the expiry check and one for the 90 day login window
with subscription_reference as (
select max(coalesce(end_date,start_date)) as report_date
from subscriptions),
activity_reference as (
select max(event_date) as report_date
from user_activity),
latest_subscription as (
select customer_id, status, end_date
from (
select customer_id, status, end_date,
row_number() over (partition by customer_id order by start_date desc) as rn
from subscriptions) ranked
where rn = 1),
latest_login as (
select customer_id, max(event_date) as last_login
from user_activity
where event_type = 'Login'
group by customer_id)
select c.customer_id, c.name, c.country,
case when ls.status = 'Canceled'
or (ls.status = 'Active' and ls.end_date is not null and ls.end_date < sr.report_date) then 'Financial Churn'
when ls.status = 'Active'
and (ll.last_login is null or ll.last_login < ar.report_date - interval 90 day) then 'Engagement Risk'
when ls.customer_id is null then 'No Subscription'
else 'Active' end as customer_segment
from customers c
left join latest_subscription ls on c.customer_id = ls.customer_id
left join latest_login ll on c.customer_id = ll.customer_id
cross join subscription_reference sr
cross join activity_reference ar;
