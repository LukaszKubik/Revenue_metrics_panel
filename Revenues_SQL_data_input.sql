WITH user_payments AS (
    SELECT
        u.user_id,
        u.game_name,
        u.language,
        u.has_older_device_model,
        u.age,
        p.payment_date,
        p.revenue_amount_usd,
        DATE_TRUNC('month', p.payment_date) AS payment_month
    FROM
        project.games_paid_users as u
    JOIN
        project.games_payments as p
    ON
        u.user_id = p.user_id
),
monthly_revenue AS (
    SELECT
        payment_month,
        SUM(revenue_amount_usd) AS total_revenue,
        COUNT(DISTINCT user_id) AS paid_users
    FROM
        user_payments
    GROUP BY
        payment_month
),
new_paid_users AS (
    SELECT
        payment_month,
        COUNT(DISTINCT user_id) AS new_paid_users
    FROM
        user_payments
    WHERE
        payment_date = (
            SELECT MIN(payment_date)
            FROM user_payments AS sub
            WHERE sub.user_id = user_payments.user_id
        )
    GROUP BY
        payment_month
),
previous_month_data AS (
    SELECT
        payment_month,
        LAG(paid_users) OVER (ORDER BY payment_month) AS prev_paid_users,
        LAG(total_revenue) OVER (ORDER BY payment_month) AS prev_total_revenue
    FROM
        monthly_revenue
)
SELECT
    mr.payment_month as Payment_Month,
    mr.total_revenue AS MRR,
    mr.paid_users AS Paid_Users,
    mr.total_revenue / mr.paid_users AS ARPPU,
    np.new_paid_users AS New_Paid_Users,
    np.new_paid_users * (mr.total_revenue / mr.paid_users) AS New_MRR,
    COALESCE(pmd.prev_paid_users, 0) - mr.paid_users + np.new_paid_users AS Churned_Users,
    100.0 * (COALESCE(pmd.prev_paid_users, 0) - mr.paid_users + np.new_paid_users) / COALESCE(pmd.prev_paid_users, 1) AS Churn_Rate,
    (COALESCE(pmd.prev_paid_users, 0) - mr.paid_users + np.new_paid_users) * coalesce(pmd.prev_total_revenue / pmd.prev_paid_users, 1) AS Churned_Revenue,
    100.0 * (COALESCE(pmd.prev_paid_users, 0) - mr.paid_users + np.new_paid_users) * coalesce (pmd.prev_total_revenue / pmd.prev_paid_users, 1) / coalesce (pmd.prev_total_revenue, 1) AS Revenue_Churn_Rate
FROM
    monthly_revenue as mr
LEFT JOIN
    new_paid_users as np ON mr.payment_month = np.payment_month
LEFT JOIN
    previous_month_data as pmd ON mr.payment_month = pmd.payment_month
ORDER BY
    mr.payment_month;