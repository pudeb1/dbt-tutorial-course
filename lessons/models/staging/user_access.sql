-- Change from iso alpha 3 country code to iso alpha 2.
WITH user_data_iso_alpha2 AS (
    SELECT
        -- noqa: disable=capitalisation.identifiers
        raw_user_data.Email AS email,
        raw_user_data.EmploymentStatus AS employment_status,
        iso3166_country_codes.alpha2_code AS country_code,
        raw_user_data.BusinessUnitName AS business_unit_name,
        raw_user_data.BusinessUnitCode AS business_unit_code,
		raw_user_data.CostCenterCode AS cost_center_code,
        raw_user_data.CostCenterName AS cost_center_name,
		row_number() over (partition by raw_user_data.Email order by raw_user_data.CostCenterCode desc) as rank_user_by_cost_center

    FROM {{ source('people_user_access', 'people_data_row_level') }} AS raw_user_data
    LEFT JOIN {{ ref('seed__country_codes_iso3166') }} AS iso3166_country_codes
        ON raw_user_data.Country_Key = iso3166_country_codes.alpha3_code
    WHERE 1 = 1
        AND raw_user_data.EmploymentStatus = 'Active'
        -- noqa: enable=all
)

-- Use business unit code and country code to determine access.
SELECT DISTINCT
    user_data_iso_alpha2.email,
    user_data_iso_alpha2.employment_status,
    user_data_iso_alpha2.country_code,
    user_data_iso_alpha2.business_unit_name,
    user_data_iso_alpha2.business_unit_code,
	user_data_iso_alpha2.cost_center_code,
    user_data_iso_alpha2.cost_center_name
FROM user_data_iso_alpha2
WHERE
	1=1
-- Filter below allows to remove duplicate email ids having multiple cost center assignment
    AND rank_user_by_cost_center =1