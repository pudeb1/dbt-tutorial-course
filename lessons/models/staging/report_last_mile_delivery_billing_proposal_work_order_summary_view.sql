{{ config(materialized='view') }}

SELECT
    work_order_completion_date,
    country AS work_order_country,
	CONCAT ('*','|',UPPER(country)) as access_key,
    service_product_number,
    hub_unit,
    postcode,
    indirect_indicator,
    billing_proposal_type,
    supplier,
    sending_unit,
    selling_unit,
    shipment_type,
    billing_proposal_status,
    effective_volume,
    volume_unit,
    effective_weight,
    weight_unit,
    service_amount_net,
    goods_amount_net,
    sales_order_currency_code AS order_currency_code,
    effective_cost,
    billing_proposal_currency,
    number_of_delivered_work_order,
    number_of_sales_order,
    number_of_settled_work_order
FROM
    {{ ref('last_mile_delivery_billing_proposal_work_order_summary') }}
