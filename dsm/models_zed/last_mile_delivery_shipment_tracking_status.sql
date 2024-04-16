CREATE OR REPLACE VIEW
ingka-dsm-dpsustain-dev.derived_zed.last_mile_delivery_shipment_tracking_status AS
with
track_status_source as (
    select
        track.region,
        track.identifier as work_order_identifier,
        track.shipment_global_id as shipment_global_identifier,
        track_hist.event_time_utc ,
        track_hist.reason_comment,
        REPLACE(
            REPLACE(
                REPLACE(
                    REPLACE(
                        UPPER(TRIM(track_hist.tracking_status_code)), '.', ':'
                    ),
                    '!',
                    '1'
                ),
                'CME',
                ''
            ),
            ':0',
            ':'
        )
            as shipment_tracking_code
    from
        `ingka-dsm-dplmdelivery-prod.prepared.lastmile_delivery_shipment_tracking_status`
            as track
    cross join
        UNNEST(track.tracking_status_history) as track_hist
    where
        1 = 1
),
track_status_enriched as (
    select
        trck.region,
        trck.shipment_global_identifier,
        trck.work_order_identifier,
        trck.event_time_utc,
        sum(case when trck.shipment_tracking_code = "92" then 1 else 0 end)
            over (partition by trck.region, trck.work_order_identifier)
            as count_loaded_on_truck,
        sum(case when trck.shipment_tracking_code = "99" then 1 else 0 end)
            over (partition by trck.region, trck.work_order_identifier)
            as count_delivery,
        sum(
            case
                when
                    upper(trck.shipment_tracking_code) = "WOVEHICLEDATA"
                    then 1
                else 0
            end
        )
            over (partition by trck.region, trck.work_order_identifier)
            as count_vehicle_info,

        first_value(
            case
                when
                    upper(trck.shipment_tracking_code) = "WOVEHICLEDATA"
                    then trck.event_time_utc
            end ignore nulls
        )
            over rows_before_delivery as vehicle_status_utc_timestamp,
        first_value(
            case
                when
                    trck.shipment_tracking_code = "92"
                    then trck.event_time_utc
            end ignore nulls
        )
            over rows_before_delivery as loaded_on_truck_utc_timestamp,
        first_value(
            case
                when
                    trck.shipment_tracking_code = "99"
                    then trck.event_time_utc
            end ignore nulls
        )
            over rows_before_delivery as shipment_delivery_utc_timestamp,
        first_value(
            case
                when
                    upper(trck.shipment_tracking_code) not in (
                        "92", "99", "WOVEHICLEDATA"
                    )
                    then trck.event_time_utc
            end ignore nulls
        )
            over rows_before_delivery as other_status_utc_timestamp,

        first_value(
            case
                when
                    upper(trck.shipment_tracking_code) = "WOVEHICLEDATA"
                    then trck.reason_comment
            end ignore nulls
        )
            over rows_all as fuel_type,

        (trck.shipment_tracking_code = "99") as delivery_flag
    from
        track_status_source as trck
    window
        rows_before_delivery as
        (
            partition by region, work_order_identifier order by
                event_time_utc desc,
                case
                    when trck.shipment_tracking_code = "92" then "X"
                    when trck.shipment_tracking_code = "WOVEHICLEDATA" then "Y"
                    when trck.shipment_tracking_code = "99" then "Z"
                    else trck.shipment_tracking_code
                end desc
            rows between current row and unbounded following
        ),
        rows_all as
        (
            partition by region, work_order_identifier
            order by
                case
                    when trck.shipment_tracking_code = "WOVEHICLEDATA"
                        then 1
                    else 2
                end,
                event_time_utc desc
        )
),
track_status_deliveries as (
    select
        *,
        row_number()
            over (
                partition by region, work_order_identifier
                order by track_status_enriched.event_time_utc desc
            )
            as rownum_last_delivery
    from track_status_enriched
    where delivery_flag
),

track_status_distinct as (
    select *
    from track_status_deliveries
    where rownum_last_delivery = 1
)

select
    region,
    shipment_global_identifier,
    work_order_identifier,
    event_time_utc AS current_event_utc_timestamp,
    loaded_on_truck_utc_timestamp,
    shipment_delivery_utc_timestamp,
    vehicle_status_utc_timestamp,
    other_status_utc_timestamp,
    count_loaded_on_truck,
    count_delivery,
    count_vehicle_info,
    fuel_type
from track_status_distinct
