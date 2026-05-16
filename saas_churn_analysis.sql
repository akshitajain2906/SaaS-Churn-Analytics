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
with reference_date as( 
select max(coalesce(end_date,start_date)) as report_date
from subscriptions)
select count(*) as active_subscriptions
from subscriptions s cross join reference_date r 
where s.start_date <= r.report_date
and (s.end_date is null 
or s.end_date >= r.report_date) 
and s.status = 'Active';

-- Section 2 - Financial Churn and Revenue Impact
-- a) Financial Churn Customers
with reference_date as(
select max(coalesce(end_date,start_date)) as report_date from subscriptions)
select s.customer_id 
from subscriptions s  cross join reference_date r
where s.status = 'Canceled'
or (s.status = 'Active'
and s.end_date < r.report_date and s.end_date is not null);

-- b) Churn Rate
with reference_date as (
select max(coalesce(end_date,start_date)) as report_date from subscriptions)
select round(
sum(case when s.status = 'Canceled' or
(s.status = 'Active' and s.end_date < r.report_date and s.end_date is not null) then 1 else 0 end )/count(*) * 100,2) as churn_rate
from subscriptions s cross join reference_date r;

-- c) Revenue Lost from Churned Customers
with reference_date as (
select max(coalesce(end_date,start_date)) as report_date
from subscriptions)
select round(sum(t.amount),2) as churned_revenue
from transactions t
join subscriptions s
on t.customer_id = s.customer_id
cross join reference_date r
where s.status = 'Canceled'
or (s.status = 'Active' and s.end_date is not null and s.end_date < r.report_date);

-- Section 3 - Revenue
-- a) Total Revenue
select round(sum(amount),2) as total_revenue
from transactions;

-- b) Lifetime Revenue per Customer
select customer_id, round(sum(amount),2) as lifetime_revenue
from transactions
group by customer_id
order by lifetime_revenue desc;

-- Section 4 - Engagement
-- a) Last Login per User
select customer_id, max(event_date) as last_login_date
from user_activity
where event_type = 'Login'
group by customer_id;

-- b) Engagement Churn - Active Subscriptions Only
with reference_date as(
select max(event_date) as report_date from user_activity )
select s.customer_id
from subscriptions s
left join user_activity ua
on s.customer_id = ua.customer_id
and ua.event_type = 'Login'
where s.status = 'Active'
group by s.customer_id
having max(ua.event_date) is null or max(ua.event_date) < (select report_date from reference_date) - interval 90 day;

-- Section 5 - Silent Churn (Feature Usage)
with reference_date as (
select max(event_date) as report_date from user_activity)
select s.customer_id
from subscriptions s
left join user_activity ua
on s.customer_id = ua.customer_id
and ua.event_type = 'Feature_Usage'
where s.status = 'Active'
group by s.customer_id
having max(ua.event_date) is null or
max(ua.event_date) < (select report_date from reference_date) - interval 90 day;

-- Section 6 - Final Customer Classification 
with subscription_reference as (
select max(coalesce(end_date,start_date)) as report_date
from subscriptions),
activity_reference as (
select max(event_date) as report_date
from user_activity),
latest_login as (
select customer_id, max(event_date) as last_login
from user_activity
where event_type = 'Login'
group by customer_id)
select c.customer_id, c.name, c.country,
case when s.status = 'Canceled'
or (s.status = 'Active' and s.end_date is not null and s.end_date < sr.report_date) then 'Financial Churn'
when s.status = 'Active'
and (ll.last_login is null or ll.last_login < ar.report_date - interval 90 day) then 'Engagement Risk'
else 'Active' end as customer_status
from customers c
left join subscriptions s on c.customer_id = s.customer_id
left join latest_login ll on c.customer_id = ll.customer_id
cross join subscription_reference sr
cross join activity_reference ar;
