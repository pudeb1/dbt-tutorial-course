{{ config(materialized='view') }}

SELECT DISTINCT
    email,
    employment_status,
    country_code,
    cost_center_code,
    cost_center_name,
    business_unit_name,
    business_unit_code,
-- Access logic based on Sourcing Dashboard User profile . ITO and BSU gets full access Service Office gets access to country
    CASE
        WHEN ( business_unit_code LIKE 'ITO%' OR business_unit_code LIKE 'BSU%') THEN '*'
        WHEN (REPLACE(UPPER(TRIM(cost_center_name)), ' ', '') = 'RE-INVOICEINTER-COMPANY') THEN '*'
        WHEN business_unit_code LIKE  'SO%' THEN country_code
        ELSE substr(business_unit_code,1,3)
    END AS access_id
FROM
    FROM {{ ref('user_access') }}