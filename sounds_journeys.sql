/*
 Initial investigation into journeys on Sounds

 1. What platforms send play start/extend/complete labels?
 2. What labels are there for clicks to content?
 3. Are there any issues with things like autoplay? - just seems to be a label
 4. Need only UK people? Or need to be able to identify where they're from - include everyone for now
 5. ID of clicks and starts?
 */

------------------ 1. What platforms send play start/extend/complete labels? ------------------
-- Only mobile, iOS and Android
-- iOS 11.3.0 onwards
-- Android 5.0.x onwards
SELECT distinct destination,
                attribute,
                CASE
                    WHEN metadata ILIKE '%responsive%' THEN 'responsive'
                    WHEN metadata ILIKE '%mobile-app%' THEN 'mobile'
                    WHEN metadata ILIKE '%bigscreen%' THEN 'bigscreen'
                    ELSE 'unknown' END as platform,
                count(*)
FROM s3_audience.publisher
WHERE attribute in ('episode~start', 'episode~extended-play', 'episode~complete')
  AND dt = 20210322
GROUP BY 1,2,3;

with visits as (
    SELECT DISTINCT dt, visit_id
    FROM s3_audience.publisher
    WHERE attribute in ('episode~start')--, 'episode~extended-play', 'episode~complete')
      AND dt = 20210322
      AND destination = 'PS_SOUNDS'),
     op_version as (
         SELECT distinct a.dt, a.visit_id, operating_system_and_version, application_version
         FROM s3_audience.audience_activity a
                  JOIN visits b on a.dt = b.dt and a.visit_id = b.visit_id
         WHERE a.dt = 20210322
           AND a.destination = 'PS_SOUNDS'
     )
SELECT distinct operating_system_and_version, application_version, count(distinct visit_id) as visits
FROM op_version
GROUP BY 1,2;

------------------ 2. What labels are there for clicks to content? ------------------
/*
 'content~select' -- individual content items
'episode-list~select' - sends you to a TLEO equivalent page
'content~autoplay' - autoplay
'content~previous' - within the player for a series to move episodes
'content~next'- within the player for a series to move episodes
'content~next-button' -- supposed to be the same as above - both seem to be sending
'content~previous-button' -- supposed to be the same as above - both seem to be sending
'push-notification~open' -- like a deeplink - are there other deeplinks into Sounds?

 'station~select' --in the spec and coming through but i couldn't make the labels send
'stations-and-schedules~select' ---in the spec and coming through but i couldn't make the labels send
 */

SELECT distinct --placement,
                --container,
                attribute,
                sum(publisher_clicks)      as clicks,
                sum(publisher_impressions) as impressions
FROM s3_audience.publisher
WHERE dt = 20210322
  AND destination = 'PS_SOUNDS'
  AND metadata ILIKE '%mobile-app%'
GROUP BY 1--, 2, 3
ORDER BY 2 DESC;

------------------ 5. IDs of clicks and starts? ------------------
SELECT * FROM s3_audience.publisher
WHERE dt = 20210322
  AND destination = 'PS_SOUNDS'
  AND metadata ILIKE '%mobile-app%'
AND visit_id in (12,13,14,15,21)
ORDER BY visit_id, event_position;

SELECT distinct visit_id,
                event_position,
                placement,
                container,
                attribute
FROM s3_audience.publisher
WHERE dt = 20210322
  AND destination = 'PS_SOUNDS'
  AND metadata ILIKE '%mobile-app%'
  AND (attribute in
       ('content~select',
        'episode-list~select',
        'mysounds~select',
        'content~autoplay',
        'music~select',
        'follows-list~select',
        'content~previous',
        'content~next',
        'up-next-list~select',
        'content~next-button',
        'favourites-list~select',
        'content~previous-button',
        'up-next-list~open',
        'push-notification~open') --these are clicks to content
    OR attribute in
       ('episode~request', 'episode~start', 'episode~extended-play', 'episode~complete') --these are the viewing flags
    )
  AND publisher_clicks = 1
ORDER BY visit_id, event_position
LIMIT 100
;