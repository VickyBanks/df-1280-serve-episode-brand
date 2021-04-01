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
SELECT DISTINCT destination,
                dt,
                visit_id,
                hashed_id,
                app_type,
                app_name,
                device_type,
                event_position::INT                                                    as page_position,
                page_name,
                central_insights_sandbox.udf_dataforce_pagename_content_ids(page_name) AS content_id
FROM s3_audience.audience_activity
WHERE destination = 'PS_SOUNDS'
  AND dt between 20210322 and 20210328
  AND is_signed_in = true
  AND geo_country_site_visited = 'United Kingdom'
  AND source = 'Events'
  AND NOT (page_name = 'keepalive'
    OR page_name ILIKE '%mvt.activated%'
    OR page_name ILIKE 'iplayer.load.page'
    OR page_name ILIKE 'sounds.startup.page'
    OR page_name ILIKE 'sounds.load.page')
LIMIT 100
;