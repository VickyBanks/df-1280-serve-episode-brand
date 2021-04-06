--Label checking
SELECT CASE
           WHEN metadata ILIKE '%responsive%' THEN 'responsive'
           WHEN metadata ILIKE '%mobile-app%' THEN 'mobile'
           WHEN metadata ILIKE '%bigscreen%' THEN 'bigscreen'
           ELSE 'unknown' END as platform,
       placement,
       container,
       attribute,
       result,
       CASE
           WHEN result IN (SELECT distinct episode_id from dataforce_sandbox.vb_vmb) THEN 'ep_id'
           WHEN result IN (SELECT distinct series_id from dataforce_sandbox.vb_vmb) THEN 'series_id'
           WHEN result IN (SELECT distinct brand_id from dataforce_sandbox.vb_vmb) THEN 'brand_id'
           WHEN result IN (SELECT distinct master_brand_id from dataforce_sandbox.vb_vmb) THEN 'master_brand_id'
           ELSE 'unknown' END as id_type,
       user_experience
FROM s3_audience.publisher
WHERE destination = 'PS_SOUNDS'
  AND dt = 20210330
  AND placement = 'sounds.page'    --homepage/listen page
  --AND container in ('priority_brands', -- unmissable sounds podcast rail
  --                  'music_mixes') --music mix rail
  AND attribute in ('episode-list~select', -- takes the user to the TLEO page
                    'content~select') --takes the user to the item
  AND publisher_clicks = 1
LIMIT 100;

--container = 'priority_brands'
--attribute = 'episode-list~select'
/*
 Creation id = attribute
 Campaign id = container
 */


--- The label 'content~select' is for individual items
-- The label 'episode-list~select' is for individual items that take you to a TLEO page OR for the 'more-episodes' button
-- We want to look at the proportion of clicks to each label, only for the rails where both are availle
DROp TABLE dataforce_sandbox.vb_uk_sounds_visits;
CREATE TABLE dataforce_sandbox.vb_uk_sounds_visits AS
with uk_visits AS (
    SELECT distinct dt, visit_id
    FROM s3_audience.audience_activity
    WHERE destination = 'PS_SOUNDS'
      AND dt between 20210322 and 20210328
      AND app_name = 'sounds'
      AND geo_country_site_visited = 'United Kingdom'
),
     clicks as (
         SELECT  CASE
                             WHEN metadata ILIKE '%responsive%' THEN 'responsive'
                             WHEN metadata ILIKE '%mobile-app%' THEN 'mobile'
                             WHEN metadata ILIKE '%bigscreen%' THEN 'bigscreen'
                             ELSE 'unknown' END as platform,
                         placement,
                         container,
                         attribute,
                         CASE
                             WHEN result IN (SELECT distinct episode_id from dataforce_sandbox.vb_vmb) THEN 'ep_id'
                             WHEN result IN (SELECT distinct series_id from dataforce_sandbox.vb_vmb) THEN 'series_id'
                             WHEN result IN (SELECT distinct brand_id from dataforce_sandbox.vb_vmb) THEN 'brand_id'
                             WHEN result IN (SELECT distinct master_brand_id from dataforce_sandbox.vb_vmb)
                                 THEN 'master_brand_id'
                             ELSE 'unknown' END as id_type
         FROM s3_audience.publisher
         WHERE destination = 'PS_SOUNDS'
           AND dt between 20210322 and 20210328
           AND dt || visit_id in (SELECT distinct dt || visit_id from uk_visits)
           AND placement = 'sounds.page'       --homepage/listen page
           --AND container in ('priority_brands', -- unmissable sounds podcast rail
           --                  'music_mixes') --music mix rail
           AND attribute in ('episode-list~select', -- takes the user to the TLEO page
                             'content~select') --takes the user to the item
           AND publisher_clicks = 1)

SELECT *, count(*) as clicks
FROM clicks
GROUP BY 1, 2, 3, 4, 5;

SELECT * FROM dataforce_sandbox.vb_uk_sounds_visits;


--- Get the pages people went to
SELECT DISTINCT dt,
                visit_id,
                hashed_id,
                app_type,
                event_position::INT                                                    as page_position,
                page_name,
                central_insights_sandbox.udf_dataforce_pagename_content_ids(page_name) AS content_id,
                central_insights_sandbox.udf_dataforce_page_type(page_name)            AS page_type,
                CASE
                    WHEN page_type IN ('schedule_page', 'stations') THEN 'Stations & Schedules'
                    WHEN page_type IN ('my_sounds_bookmarks', 'my_sounds_latest', 'my_sounds_subscribed')
                        THEN 'My Sounds'
                    WHEN page_type IN ('live_playspace', 'live_playspace_pop_out') THEN 'Live Playspace'
                    WHEN page_type = 'od_playspace' THEN 'On-Demand Playspace'
                    WHEN page_type = 'listen_page' THEN 'Listen Page'
                    WHEN page_type IN ('tag_page', 'category_page') THEN 'Category Page'
                    WHEN page_type = 'tleo_page' THEN 'TLEO (Brand/Series) Page'
                    ELSE 'Other Page' END                                              AS page_type_new--,
                --row_number() over (partition by dt, visit_id, page_name ORDER )
                --sum(playback_time) as playback_time_total

FROM s3_audience.audience_activity
WHERE destination = 'PS_SOUNDS'
  AND dt = 20210322 --between 20210322 and 20210328
  AND is_signed_in = true
  AND geo_country_site_visited = 'United Kingdom'
  --AND source = 'Events'
  AND NOT (page_name = 'keepalive'
    OR page_name ILIKE '%mvt.activated%'
    OR page_name ILIKE 'iplayer.load.page'
    OR page_name ILIKE 'sounds.startup.page'
    OR page_name ILIKE 'sounds.load.page')
  AND (page_name ILIKE '%play%' or page_name ILIKE '%brand%')
AND page_name NOT ILIKE '%world service%'

ORDER BY dt, visit_id, event_position
LIMIT 100
;

-------- Mimic the journeys work to get sequential pages --------
---------- Script to get journeys --------------

-- Step 1: Get consecutive pages for each visit in the date range
DROP TABLE IF EXISTS central_insights_sandbox.vb_sounds_journey_pages;
CREATE TABLE central_insights_sandbox.vb_sounds_journey_pages AS
SELECT destination,
       dt,
       visit_id,
       hashed_id,
       app_type,
       app_name,
       device_type,
       event_position::INT as page_position,
       page_name,
       central_insights_sandbox.udf_dataforce_pagename_content_ids(page_name) AS content_id,
       central_insights_sandbox.udf_dataforce_page_type(page_name)            AS page_type,
                CASE
                    WHEN page_type IN ('schedule_page', 'stations') THEN 'Stations & Schedules'
                    WHEN page_type IN ('my_sounds_bookmarks', 'my_sounds_latest', 'my_sounds_subscribed')
                        THEN 'My Sounds'
                    WHEN page_type IN ('live_playspace', 'live_playspace_pop_out') THEN 'Live Playspace'
                    WHEN page_type = 'od_playspace' THEN 'On-Demand Playspace'
                    WHEN page_type = 'listen_page' THEN 'Listen Page'
                    WHEN page_type IN ('tag_page', 'category_page') THEN 'Category Page'
                    WHEN page_type = 'tleo_page' THEN 'TLEO (Brand/Series) Page'
                    ELSE 'Other Page' END                                              AS page_type_simple
FROM s3_audience.audience_activity
WHERE destination = 'PS_SOUNDS'
  AND  dt = 20210322 --between 20210322 and 20210328
  AND is_signed_in = true
  AND geo_country_site_visited = 'United Kingdom'
  AND ((destination = 'PS_SOUNDS' and source = 'Events') OR destination = 'PS_IPLAYER') -- correct source for each destination
  AND NOT (page_name = 'keepalive'
    OR page_name ILIKE '%mvt.activated%'
    OR page_name ILIKE 'iplayer.load.page'
    OR page_name ILIKE 'sounds.startup.page'
    OR page_name ILIKE 'sounds.load.page')
;

SELECT * FROM central_insights_sandbox.vb_sounds_journey_pages WHERE visit_id = 15 ORDER BY dt, visit_id, page_position LIMIT 100;

SELECT * FROM s3_audience.audience_activity
WHERE destination = 'PS_SOUNDS'
  AND  dt = 20210322 AND visit_id = 15;

-- Step 2: Remove duplicate consecutive pages
-- Step 2a - find previous page
drop table if exists central_insights_sandbox.vb_sounds_journey_deduped_pages;
create table central_insights_sandbox.vb_sounds_journey_deduped_pages as
select destination,
       dt,
       visit_id,
       hashed_id,
       app_type,
       app_name,
       device_type,
       page_position,
       page_name,
       content_id,
       page_type,
       page_type_simple,
       lag(page_name, 1) over (partition by dt, visit_id, destination order by page_position::INT asc) as prev_page
from central_insights_sandbox.vb_sounds_journey_pages
;

-- Step 2b - remove any duplicates
delete
from central_insights_sandbox.vb_sounds_journey_deduped_pages
where page_name = prev_page;

alter table central_insights_sandbox.vb_sounds_journey_deduped_pages
    drop column prev_page;

SELECT * FROM central_insights_sandbox.vb_sounds_journey_deduped_pages ORDER BY dt, visit_id, page_position LIMIT 100;

--sounds.play.w3ct1rfd.page
--sounds.brand.p09b3h1l.page
--sounds.play.p09bts3r.page

--- Get playback times for pages
DROP TABLE IF EXISTS central_insights_sandbox.vb_sounds_journey_playback;
CREATE TABLE central_insights_sandbox.vb_sounds_journey_playback AS
SELECT destination,
       dt,
       visit_id,
       hashed_id,
       app_type,
       app_name,
       device_type,
       event_position::INT                                                    as page_position,
       page_name,
       central_insights_sandbox.udf_dataforce_pagename_content_ids(page_name) AS content_id,
       version_id,
       play_id,
       central_insights_sandbox.udf_dataforce_page_type(page_name)            AS page_type,
       CASE
           WHEN page_type IN ('schedule_page', 'stations') THEN 'Stations & Schedules'
           WHEN page_type IN ('my_sounds_bookmarks', 'my_sounds_latest', 'my_sounds_subscribed')
               THEN 'My Sounds'
           WHEN page_type IN ('live_playspace', 'live_playspace_pop_out') THEN 'Live Playspace'
           WHEN page_type = 'od_playspace' THEN 'On-Demand Playspace'
           WHEN page_type = 'listen_page' THEN 'Listen Page'
           WHEN page_type IN ('tag_page', 'category_page') THEN 'Category Page'
           WHEN page_type = 'tleo_page' THEN 'TLEO (Brand/Series) Page'
           ELSE 'Other Page' END                                              AS page_type_simple,
       --sum(playback_time) as playback_time_total
       playback_time
FROM s3_audience.audience_activity
WHERE destination = 'PS_SOUNDS'
  AND dt = 20210322 --between 20210322 and 20210328
  AND is_signed_in = true
  AND geo_country_site_visited = 'United Kingdom'
  AND NOT (page_name = 'keepalive'
    OR page_name ILIKE '%mvt.activated%'
    OR page_name ILIKE 'iplayer.load.page'
    OR page_name ILIKE 'sounds.startup.page'
    OR page_name ILIKE 'sounds.load.page')
--GROUP BY 1,2,3,4,5,6,7,8,9,10
;

SELECT * FROM central_insights_sandbox.vb_sounds_journey_playback  WHERE visit_id in(13, 15,25) ORDER BY dt, visit_id, page_position ;
SELECT visit_id, page_name, play_id, sum(playback_time)
FROM central_insights_sandbox.vb_sounds_journey_playback
WHERE visit_id in(13, 15,25)
GROUP BY 1,2,3
ORDER BY visit_id;

-- Need to find a way to join in the pages with playback time to the page list BUT if they go away and return we need to de-dup
-- ALSO how does playback time work when they've got the persistent player?

--- What's happening in publisher?
/*
 These are all click labels
content~autoplay
episode~request
episode~start
episode~extended-play
episode~complete

 The autoplay label sends and then the request label both as a click to start the content.
 BUT not all devices have these labels yet.
 */
SELECT * FROM s3_audience.publisher
WHERE destination = 'PS_SOUNDS'
  AND dt = 20210322
AND visit_id = 15;