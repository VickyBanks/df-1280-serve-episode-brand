/*
 Initial investigation into journeys on Sounds

 1. What platforms send play start/extend/complete labels?
 2. What labels are there for clicks to content?
 3. What labels are there for clicks to actually play content?
 4. Are there any issues with things like autoplay? - just seems to be a label for AOD but nothing for live.
 5. Need only UK people? Or need to be able to identify where they're from - include everyone for now
 6. ID of clicks and starts? - AOD focus
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

SELECT visit_id,
       event_position,
       placement,
       container,
       attribute,
       result,
       central_insights_sandbox.udf_dataforce_pagename_content_ids(placement) AS content_id,
       central_insights_sandbox.udf_dataforce_page_type(placement)            AS page_type,
       CASE
           WHEN page_type IN ('schedule_page', 'stations') THEN 'Stations & Schedules'
           WHEN page_type IN ('my_sounds_bookmarks', 'my_sounds_latest', 'my_sounds_subscribed')
               THEN 'My Sounds'
           WHEN page_type IN ('live_playspace', 'live_playspace_pop_out') THEN 'Live Playspace'
           WHEN page_type = 'od_playspace' THEN 'On-Demand Playspace'
           WHEN page_type = 'listen_page' THEN 'Listen Page'
           WHEN page_type IN ('tag_page', 'category_page') THEN 'Category Page'
           WHEN page_type = 'tleo_page' THEN 'TLEO (Brand/Series) Page'
           ELSE 'Other Page' END                                              AS page_type_ne
FROM s3_audience.publisher
WHERE dt = 20210322
  AND destination = 'PS_SOUNDS'
  AND metadata ILIKE '%mobile-app%'
 /* AND (attribute in
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
    )*/
  AND publisher_clicks = 1
  AND visit_id in ( 101, 102, 103) -- just to find some different examples
ORDER BY visit_id, event_position

;

------------------ 3. What labels are there for clicks to actually start playing ------------------
/*
| Description                               | Container       | Attribute           |
| ----------------------------------------- | --------------- | ------------------- |
| The live radio player                     | `listen-live`   | `content-select`    |
| In the player page                        | `Application`   | `play-start~click`  |
| On a TLEO plage with the quick play icon. | `list-tleo`     | `quick-player~play` |
| The player at the bottom of the page      | `Application`   | `play-start~click`  |
| Any quick play icon sends                 | many containers | `quick-player~play` |
| On this episode page                      | `episode`       | `episode-play`      |

For actually starting playing these seem to be the labels.
 */

SELECT --visit_id,
       --event_position,
       DISTINCT --placement,
       container,
       attribute,
       --result,
       --central_insights_sandbox.udf_dataforce_pagename_content_ids(placement) AS content_id,
       central_insights_sandbox.udf_dataforce_page_type(placement)            AS page_type,
       CASE
           WHEN page_type IN ('schedule_page', 'stations') THEN 'Stations & Schedules'
           WHEN page_type IN ('my_sounds_bookmarks', 'my_sounds_latest', 'my_sounds_subscribed')
               THEN 'My Sounds'
           WHEN page_type IN ('live_playspace', 'live_playspace_pop_out') THEN 'Live Playspace'
           WHEN page_type = 'od_playspace' THEN 'On-Demand Playspace'
           WHEN page_type = 'listen_page' THEN 'Listen Page'
           WHEN page_type IN ('tag_page', 'category_page') THEN 'Category Page'
           WHEN page_type = 'tleo_page' THEN 'TLEO (Brand/Series) Page'
           ELSE 'Other Page' END                                              AS page_type_new,
       count(*)
FROM s3_audience.publisher
WHERE dt = 20210322
  AND destination = 'PS_SOUNDS'
  AND metadata ILIKE '%mobile-app%'
AND publisher_clicks = 1
  AND (attribute in ('play-start~click', 'quick-player~play') OR
       (attribute = 'content~select' AND container = 'listen_live'))

GROUP BY 1,2,3,4;

-- Combine labels to categorise things.
SELECT visit_id,
       event_position,
       placement,
       container,
       attribute,
       result,
       CASE
           WHEN central_insights_sandbox.udf_dataforce_page_type(placement) IN ('schedule_page', 'stations')
               THEN 'Stations & Schedules'
           WHEN central_insights_sandbox.udf_dataforce_page_type(placement) IN
                ('my_sounds_bookmarks', 'my_sounds_latest', 'my_sounds_subscribed')
               THEN 'My Sounds'
           WHEN central_insights_sandbox.udf_dataforce_page_type(placement) IN
                ('live_playspace', 'live_playspace_pop_out') THEN 'Live Playspace'
           WHEN central_insights_sandbox.udf_dataforce_page_type(placement) = 'od_playspace' THEN 'On-Demand Playspace'
           WHEN central_insights_sandbox.udf_dataforce_page_type(placement) = 'listen_page' THEN 'Listen Page'
           WHEN central_insights_sandbox.udf_dataforce_page_type(placement) IN ('tag_page', 'category_page')
               THEN 'Category Page'
           WHEN central_insights_sandbox.udf_dataforce_page_type(placement) = 'tleo_page'
               THEN 'TLEO (Brand/Series) Page'
           ELSE 'Other Page' END AS page_type,
       CASE
           WHEN (attribute in ('play-start~click', 'quick-player~play', 'episode~play') OR
                 (attribute = 'content~select' AND container = 'listen_live')) THEN 'play_click'
           WHEN attribute in
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
                 'push-notification~open') THEN 'content_click'
           WHEN attribute in
                ('episode~request', 'episode~start', 'episode~extended-play', 'episode~complete') THEN 'play_flag'
           ELSE 'other'
           END                   as click_type,
       event_start_datetime

FROM s3_audience.publisher
WHERE dt = 20210322
  AND destination = 'PS_SOUNDS'
  AND metadata ILIKE '%mobile-app%'
  AND publisher_clicks = 1
 AND visit_id in ( 101, 102, 103)
ORDER BY visit_id, event_position
;

-- do all live plays carry the masterbrand as the result rather than a pid
SELECT result, count(distinct visit_id)
FROM s3_audience.publisher
WHERE dt = 20210322
  AND destination = 'PS_SOUNDS'
  AND metadata ILIKE '%mobile-app%'
AND container = 'player-live'
GROUP BY 1;

SELECT DISTINCT result, count(distinct visit_id)
FROM s3_audience.publisher
WHERE dt = 20210322
  AND destination = 'PS_SOUNDS'
  AND metadata ILIKE '%mobile-app%'
  AND result SIMILAR TO '%[0-9]%'
AND result NOT IN ('bbc_1xtra', 'bbc_6music','bbc_radio_cymru_2')
GROUP BY 1;

------------------ 6.  Can you match content ID labels for AUD? ------------------
with os as (
    --need to use only Android visits because of a data issue with iOS
    SELECT distinct visit_id,
                    split_part(operating_system_and_version, ' ', 1) as apple_android
    FROM s3_audience.audience_activity
    WHERE dt = 20210322
      AND destination = 'PS_SOUNDS')
SELECT visit_id,
       event_position,
       placement,
       container,
       attribute,
       result,
       brand_title,
       episode_title,
       CASE
           WHEN central_insights_sandbox.udf_dataforce_page_type(placement) IN ('schedule_page', 'stations')
               THEN 'Stations & Schedules'
           WHEN central_insights_sandbox.udf_dataforce_page_type(placement) IN
                ('my_sounds_bookmarks', 'my_sounds_latest', 'my_sounds_subscribed')
               THEN 'My Sounds'
           WHEN central_insights_sandbox.udf_dataforce_page_type(placement) IN
                ('live_playspace', 'live_playspace_pop_out') THEN 'Live Playspace'
           WHEN central_insights_sandbox.udf_dataforce_page_type(placement) = 'od_playspace' THEN 'On-Demand Playspace'
           WHEN central_insights_sandbox.udf_dataforce_page_type(placement) = 'listen_page' THEN 'Listen Page'
           WHEN central_insights_sandbox.udf_dataforce_page_type(placement) IN ('tag_page', 'category_page')
               THEN 'Category Page'
           WHEN central_insights_sandbox.udf_dataforce_page_type(placement) = 'tleo_page'
               THEN 'TLEO (Brand/Series) Page'
           ELSE 'Other Page' END AS page_type,
       CASE
           WHEN (attribute in ('play-start~click', 'quick-player~play', 'episode~play') OR
                 (attribute = 'content~select' AND container = 'listen_live')) THEN 'play_click'
           WHEN attribute in
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
                 'push-notification~open') THEN 'content_click'
           WHEN attribute in
                ('episode~request', 'episode~start', 'episode~extended-play', 'episode~complete') THEN 'play_flag'
           ELSE 'other'
           END                   as click_type,
       event_start_datetime

FROM s3_audience.publisher a
LEFT JOIN (SELECT DISTINCT brand_title,episode_title, episode_id FROM prez.scv_vmb) b ON a.result = b.episode_id
WHERE dt = 20210322
  AND destination = 'PS_SOUNDS'
  AND metadata ILIKE '%mobile-app%'
  AND publisher_clicks = 1
  AND result SIMILAR TO '%[0-9]%'
AND result NOT IN ('bbc_1xtra', 'bbc_6music','bbc_radio_cymru_2')
AND visit_id in (SELECT DISTINCT visit_id FROM os WHERE apple_android = 'Android')

AND event_start_datetime::datetime > '2021-03-22T08:00:00' -- to avoid people at midnight
ORDER BY visit_id, event_position
LIMIT 1000
;

------------------ 7.  Begin linking of journey ------------------

DROP TABLE pub_data;
CREATE TEMP TABLE pub_data AS
    with os as (
    --need to use only Android visits because of a data issue with iOS
    SELECT distinct visit_id,
                    split_part(operating_system_and_version, ' ', 1) as apple_android
    FROM s3_audience.audience_activity
    WHERE dt = 20210322
      AND destination = 'PS_SOUNDS')
SELECT dt,
       visit_id,
       event_position,
       placement,
       container,
       attribute,
       result,
       brand_title,
       episode_title,
       CASE
           WHEN central_insights_sandbox.udf_dataforce_page_type(placement) IN ('schedule_page', 'stations')
               THEN 'Stations & Schedules'
           WHEN central_insights_sandbox.udf_dataforce_page_type(placement) IN
                ('my_sounds_bookmarks', 'my_sounds_latest', 'my_sounds_subscribed')
               THEN 'My Sounds'
           WHEN central_insights_sandbox.udf_dataforce_page_type(placement) IN
                ('live_playspace', 'live_playspace_pop_out') THEN 'Live Playspace'
           WHEN central_insights_sandbox.udf_dataforce_page_type(placement) = 'od_playspace' THEN 'On-Demand Playspace'
           WHEN central_insights_sandbox.udf_dataforce_page_type(placement) = 'listen_page' THEN 'Listen Page'
           WHEN central_insights_sandbox.udf_dataforce_page_type(placement) IN ('tag_page', 'category_page')
               THEN 'Category Page'
           WHEN central_insights_sandbox.udf_dataforce_page_type(placement) = 'tleo_page'
               THEN 'TLEO (Brand/Series) Page'
           ELSE 'Other Page' END AS page_type,
       CASE
           WHEN (attribute in ('play-start~click', 'quick-player~play', 'episode~play') OR
                 (attribute = 'content~select' AND container = 'listen_live')) THEN 'play_click'
           WHEN attribute in
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
                 'push-notification~open') THEN 'content_click'
           WHEN attribute in
                ('episode~request', 'episode~start', 'episode~extended-play', 'episode~complete') THEN 'play_flag'
           ELSE 'other'
           END                   as click_type,
       event_start_datetime,
       brand_id,
       series_id

FROM s3_audience.publisher a
         LEFT JOIN (SELECT DISTINCT brand_title, brand_id, series_id, episode_title, episode_id FROM prez.scv_vmb) b
                   ON a.result = b.episode_id
WHERE dt = 20210322
  AND destination = 'PS_SOUNDS'
  AND metadata ILIKE '%mobile-app%'
  AND publisher_clicks = 1
  AND result SIMILAR TO '%[0-9]%'
  AND result NOT IN ('bbc_1xtra', 'bbc_6music', 'bbc_radio_cymru_2')
  AND (attribute IN
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
        'push-notification~open') -- clicks to content
    OR attribute in ('episode~request', 'episode~start', 'episode~extended-play', 'episode~complete') -- play flags
    OR
       (attribute in ('play-start~click', 'quick-player~play', 'episode~play') OR
        (attribute = 'content~select' AND container = 'listen_live')) -- clicking start
    )

  AND event_start_datetime::datetime > '2021-03-22T08:00:00' -- to avoid people at midnight
ORDER BY visit_id, event_position
AND visit_id in (SELECT DISTINCT visit_id FROM os WHERE apple_android = 'Android')
;

-- get a sample
SELECT * FROM pub_data
WHERE visit_id IN (262, 1262,1353,1361,2694)
ORDER BY visit_id DESC, event_position
limit 500;

-- get this full sample from publisher
SELECT * FROM  s3_audience.publisher
WHERE dt = 20210322
  AND destination = 'PS_SOUNDS'
  AND metadata ILIKE '%mobile-app%'
  AND publisher_clicks = 1
  AND result SIMILAR TO '%[0-9]%'
  AND result NOT IN ('bbc_1xtra', 'bbc_6music', 'bbc_radio_cymru_2')
AND visit_id IN (262, 1262,1353,1361,2694)
ORDER BY visit_id, event_position;

-- roll up the rows to link play metrics
DROP TABLE play_metrics;
CREATE TEMP TABLE play_metrics AS
with get_data AS ( --get all the play flags and roll up what metrics there are
    SELECT *,
           lead(attribute, 1)
           OVER (partition by dt, visit_id, result order by event_position) AS attribute_2,
           lead(attribute, 2)
           OVER (partition by dt, visit_id, result order by event_position) AS attribute_3,
           lead(attribute, 3)
           OVER (partition by dt, visit_id, result order by event_position) AS attribute_4
    FROM pub_data
    WHERE click_type = 'play_flag'
)
-- only select the ones that start with the request because that should come first.
-- What if a `episode~request` isn't sent?
SELECT * from get_data
WHERE attribute = 'episode~request'
AND visit_id IN (262, 1262,1353,1361,2694)
ORDER BY visit_id, event_position;

SELECT * FROM play_metrics ORDER BY visit_id, event_position;

-- Get all the clicks to content
DROP TABLE content_clicks;
CREATE temp table content_clicks AS
SELECT *
FROM pub_data
WHERE visit_id IN (262, 1262,1353,1361,2694)
AND click_type = 'content_click'
ORDER BY visit_id, event_position
;

-- link play metrics and content clicks
DROP TABLE click_plays_linked;
CREATE TEMP TABLE click_plays_linked as
SELECT a.dt, a.visit_id, a.event_position,a.placement, a.container, a.attribute, a.result, a.brand_id, a.series_id,
       b.event_position as start_event_pos,
       b.placement as start_placement,
       b.container as start_container,
       b.attribute as start_attribute,
       b.result as start_result,
       b.brand_id as start_brand_id,
       b.series_id as start_series_id,
       b.attribute_2,
       b.attribute_3,
       b.attribute_4,
       b.event_position - a.event_position AS event_pos_diff,
       row_number() over (partition by a.dt, a.visit_id, b.event_position ORDER BY event_pos_diff) as dup_count_1,
row_number() over (partition by a.dt, a.visit_id, a.event_position ORDER BY event_pos_diff) as dup_count_2
FROM content_clicks a
         LEFT JOIN play_metrics b on a.dt = b.dt and a.visit_id = b.visit_id
    AND a.event_position < b.event_position --the click must come before the metrics
    AND CASE
            WHEN a.brand_id IS NOT NULL THEN a.brand_id = b.brand_id
            WHEN a.series_id IS NOT NULL THEN a.series_id = b.series_id END


ORDER BY a.visit_id, a.event_position
;
SELECT * FROM click_plays_linked ORDER BY visit_id, event_position;

-- if there was a duplicate play metric linked created then set to blank
UPDATE click_plays_linked
SET start_event_pos = NULL,
    start_placement= NULL,
    start_container= NULL,
    start_attribute= NULL,
    start_result= NULL,
    start_brand_id= NULL,
    start_series_id= NULL,
    attribute_2= NULL,
    attribute_3= NULL,
    attribute_4= NULL
WHERE dup_count_1 != 1;

SELECT * FROM click_plays_linked ORDER BY visit_id, event_position;

--if the click was duplicated then remove
DELETE  FROM click_plays_linked
WHERE dup_count_2 !=1;

ALTER TABLE click_plays_linked DROP COLUMN event_pos_diff;
ALTER TABLE click_plays_linked DROP COLUMN dup_count_2;
ALTER TABLE click_plays_linked DROP COLUMN dup_count_1;

SELECT * FROM click_plays_linked ORDER BY visit_id, event_position;