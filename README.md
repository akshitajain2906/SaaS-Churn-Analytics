# SaaS Churn & Revenue Analytics

## Overview
Churn is one of the most critical metrics in any subscription business, yet most analyses stop at cancellations. This project takes a deeper approach by identifying three distinct layers of customer risk: financial churn, engagement churn, and silent churn.

The analysis covers:
- 50,000 customers
- 100,000 subscriptions
- 500,000 transactions

All insights are visualised in an interactive dashboard built in Microsoft Power BI using data prepared in MySQL.

## Tools & Technologies
- MySQL - data storage and transformation
- Microsoft Power BI - dashboard and visual analytics

## Business Questions
This analysis addresses several key business questions:
- What is the true state of the subscription base?
- How many customers have churned and what is the revenue impact?
- Which active subscribers are disengaged and at risk of cancelling?
- What is the lifetime value of each customer?
- How can customers be segmented by financial health and engagement?

## Dashboard
![Dashboard](saas_churn_dashboard.png)

## Key Findings

**Financial Churn**  
Approximately 30% of subscriptions have churned. Understanding who churned and why establishes the foundation for predicting and preventing the next wave of cancellations.

**Engagement Risk**  
19,000 subscribers remain active but have not logged in for 90 or more days. These customers represent the next likely churn segment and present a clear opportunity for proactive re-engagement before revenue is lost.

**Silent Churn**  
A segment of active subscribers shows no product feature usage in 90 or more days. These customers remain active in the system but have effectively stopped using the product.

**Upsell Opportunity**  
More than 50,000 customers are on the Basic plan, while only 19,884 are on Premium. Highly engaged customers on lower-tier plans represent the highest-probability upgrade segment, creating a scalable revenue opportunity without acquiring new customers.

## Methodology
All time-based calculations use a dynamic reference date derived from the dataset rather than hardcoded values:

```sql
WITH reference_date AS (
    SELECT MAX(COALESCE(end_date, start_date)) AS report_date
    FROM subscriptions
)
```

This ensures the analysis remains fully reproducible as new data is added.

### Churn Classification Model
The analysis distinguishes between three types of churn, which are often conflated in traditional reporting:

| Churn Type | Definition |
|---|---|
| Financial Churn | Subscription cancelled or end date passed |
| Engagement Churn | Active subscription but no login for 90+ days |
| Silent Churn | Active subscription but no feature usage for 90+ days |

### Customer Segmentation
Every customer is classified into one of three segments:
- Active - engaged and financially healthy
- Engagement Risk - active but disengaged
- Financial Churn - subscription cancelled

This segmentation allows the business to identify at-risk customers earlier and intervene before revenue is lost.
