CREATE OR REPLACE VIEW
ingka-dsm-dpsustain-dev.derived_zed.zero_emission_delivery as
WITH
tracking_status_join_shipment AS (
    SELECT
        shipment.region,
        shipment.country,
        shipment.hub_unit,
        shipment.work_order_identifier,
        shipment.service_product_number,
        shipment.transport_service_provider,
        shipment.transport_service_provider_name,
        shipment.work_order_created_utc_timestamp,
        events.current_event_utc_timestamp,
        events.loaded_on_truck_utc_timestamp,
        events.shipment_delivery_utc_timestamp,
        events.vehicle_status_utc_timestamp,
        events.other_status_utc_timestamp,
        events.fuel_type,
        events.count_loaded_on_truck,
        events.count_delivery,
        events.count_vehicle_info

    FROM
        ingka-dsm-dpsustain-dev.derived_zed.last_mile_delivery_shipment
            AS shipment
    INNER JOIN
        ingka-dsm-dpsustain-dev.derived_zed.last_mile_delivery_shipment_tracking_status
            AS events
        ON
            shipment.work_order_identifier = events.work_order_identifier
            AND shipment.region = events.region
)
,
final_with_incorrect_report_desc AS (
    SELECT
        *,
        CASE
            WHEN
                loaded_on_truck_utc_timestamp IS NOT null
                AND vehicle_status_utc_timestamp IS NOT null
                AND loaded_on_truck_utc_timestamp
                < shipment_delivery_utc_timestamp
                AND vehicle_status_utc_timestamp
                <= shipment_delivery_utc_timestamp
                AND coalesce(other_status_utc_timestamp, "1900-01-01")
                <= loaded_on_truck_utc_timestamp
                THEN 1
            ELSE 0
        END AS count_dates_in_correct_order

    FROM tracking_status_join_shipment
),
final_with_incorrect_report_flag AS (
    SELECT
        *,
        CASE WHEN count_vehicle_info = 0 THEN 0 ELSE 1 END
            AS count_vehicle_info_found,
        CASE WHEN count_loaded_on_truck > 0 THEN 0 ELSE 1 END
            AS count_loaded_on_truck_found,
        CASE
            WHEN
                (
                    count_vehicle_info = 0
                    OR count_loaded_on_truck = 0
                    OR count_dates_in_correct_order = 0
                )
                THEN 1
            ELSE 0
        END AS count_incorrectly_reported
    FROM final_with_incorrect_report_desc
),
final AS (
    SELECT
        region,
        country,
        hub_unit,
        service_product_number,
        transport_service_provider,
        transport_service_provider_name,
        date(shipment_delivery_utc_timestamp) AS shipment_delivery_date,
        coalesce(upper(fnl.fuel_type), "UNKNOWN") AS fuel_type_source,
        (coalesce(upper(fnl.fuel_type), "x") IN ("ELECTRIC", "HYDROGEN"))
            AS zero_emission_flag,
        count(DISTINCT work_order_identifier) AS count_work_order,
        sum(count_delivery) AS count_delivery,
        sum(count_vehicle_info_found) AS count_vehicle_info_found,
        sum(count_loaded_on_truck_found) AS count_loaded_on_truck_found,
        sum(count_dates_in_correct_order) AS count_dates_in_correct_order,
        sum(count_incorrectly_reported) AS count_incorrectly_reported
    FROM final_with_incorrect_report_flag AS fnl
    WHERE
        1 = 1
    GROUP BY
        region,
        country,
        hub_unit,
        service_product_number,
        transport_service_provider,
        transport_service_provider_name,
        shipment_delivery_date,
        fuel_type_source,
        zero_emission_flag
)
select
    region,
    country,
    hub_unit,
    service_product_number,
    transport_service_provider,
    transport_service_provider_name,
    shipment_delivery_date,
    fuel_type_source,
    zero_emission_flag,
    count_work_order,
    count_delivery,
    count_vehicle_info_found,
    count_loaded_on_truck_found,
    count_dates_in_correct_order,
    count_incorrectly_reported
from final