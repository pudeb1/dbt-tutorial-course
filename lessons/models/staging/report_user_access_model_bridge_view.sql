{{ config(materialized='view') }}

WITH nested_accesskey AS (
SELECT
	DISTINCT
		access_key
		FROM {{ ref('report_last_mile_delivery_billing_proposal_work_order_summary_view') }}
	)

 SELECT
  access_key_split  AS access_id,
  access_key,
 'last_mile_delivery_billing_proposal_work_order_summary' AS source

FROM
  nested_accesskey,
  UNNEST(SPLIT(access_key, '|')) AS access_key_split