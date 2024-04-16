CREATE OR REPLACE VIEW
ingka-dsm-dpsustain-dev.derived_zed.last_mile_delivery_shipment AS
WITH shipment_source AS (
    SELECT
        last_mile_delivery.region,
        last_mile_delivery.country,
        last_mile_delivery.identifier AS work_order_identifier,
        last_mile_delivery.shipment_global_id AS shipment_global_identifier,
        last_mile_delivery.work_order_created_utc_timestamp,
        last_mile_delivery.isell_order_number,
        last_mile_delivery.work_order_number,
        last_mile_delivery.service_product_number,
        last_mile_delivery.tsp_id,
        CASE
            WHEN UPPER(last_mile_delivery.hub_unit) LIKE '%NULL' THEN NULL
            ELSE CONCAT(
                SUBSTR(last_mile_delivery.hub_unit, -3),
                '-',
                SUBSTR(
                    last_mile_delivery.hub_unit,
                    1,
                    LENGTH(last_mile_delivery.hub_unit) - 3
                )
            )
        END AS hub_unit,

        ROW_NUMBER()
            OVER (
                PARTITION BY
                    last_mile_delivery.region, last_mile_delivery.identifier
                ORDER BY last_mile_delivery.prepared_update_datetime DESC
            )
            AS rownum_last_shipment
    FROM
        `ingka-dsm-dplmdelivery-prod.prepared.lastmile_delivery_shipment_tracking_status`
            AS last_mile_delivery
),
shipment_source_join_dims AS (
    SELECT
        shipment_source.region,
        shipment_source.work_order_identifier,
        shipment_source.shipment_global_identifier,
        shipment_source.work_order_created_utc_timestamp,
        shipment_source.work_order_number,
        shipment_source.isell_order_number,
        shipment_source.hub_unit,
        shipment_source.service_product_number,
        tsp.provider_name AS transport_service_provider_name,
        COALESCE(bu.country_code, shipment_source.country) AS country,
        CONCAT('CAR', '-', shipment_source.tsp_id)
            AS transport_service_provider
    FROM
        shipment_source
    INNER JOIN
        `ingka-ofd-solutiondata-dev.sustainability_stg.prm_delivery_services`
            AS st
        ON
            shipment_source.service_product_number = st.servicecode
    LEFT JOIN
        `ingka-dsm-dplmdelivery-prod.derived_common.service_provider_dimension`
            AS tsp
        ON
            (
                shipment_source.tsp_id = tsp.provider_identifier
                AND tsp.deleted_indicator = FALSE
            )
    LEFT JOIN
        `ingka-dsm-dplmdelivery-prod.derived_common.business_unit_dimension`
            AS bu
        ON
            (shipment_source.hub_unit = bu.business_unit_business_key)
    WHERE
        shipment_source.rownum_last_shipment = 1
)
SELECT
    region,
    country,
    work_order_identifier,
    shipment_global_identifier,
    isell_order_number,
    work_order_number,
    work_order_created_utc_timestamp,
    hub_unit,
    service_product_number,
    transport_service_provider,
    transport_service_provider_name
FROM
    shipment_source_join_dims
