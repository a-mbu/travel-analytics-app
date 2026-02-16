-- Stage 1: Simple staging model for flights
-- dbt will materialize this as a view

with source as (
    select * from {{ source('travel_api', 'flights') }}
),

renamed as (
    select
        id as flight_id,
        flight_number,
        airline,
        origin,
        destination,
        departure_time,
        arrival_time,
        status,
        created_at as ingested_at
    from source
)

select * from renamed
