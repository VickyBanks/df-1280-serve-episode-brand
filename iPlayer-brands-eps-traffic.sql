/*
 Is there a correlation between the success of a module and whether it gives brand/episode
 */
DROP TABLE vb_vmb;
CREATE TABLE dataforce_sandbox.vb_vmb AS
    SELECT DISTINCT brand_id, brand_title, series_id, series_title, episode_id, episode_title, version_id
    FROM prez.scv_vmb;
SELECT version_id FROM dataforce_sandbox.vb_vmb LIMIT 10;
--SELECT distinct version_id from vb_vmb;

--How many clicks to each id type are there going via TLEO or not?
with id_types AS (
    SELECT visit_id,
           click_container,
           via_tleo,
           content_id,
           CASE
               WHEN content_id IN (SELECT distinct episode_id from dataforce_sandbox.vb_vmb) THEN 'ep_id'
               WHEN content_id IN (SELECT distinct series_id from dataforce_sandbox.vb_vmb) THEN 'series_id'
               WHEN content_id IN (SELECT distinct brand_id from dataforce_sandbox.vb_vmb) THEN 'brand_id'
               ELSE 'unknown' END as id_type,
           start_flag,
           complete_flag
    FROM central_insights_sandbox.vb_journey_start_watch_complete a

    WHERE dt = 20210320
      AND app_type = 'bigscreen-html'
      AND click_placement = 'home_page'
)
SELECT via_tleo,id_type, count(*) as clicks
FROM id_types
GROUP BY 1,2;

-- How successful are brand modules vs episode modules
-- The journey table updates any brand id to be an episode id if the user starts or is taken through a TLEO so we can't use this for clicks, we need to use publishe

--this give the clicks to each container and the split of brand vs ep_id
SELECT age_range,
       CASE
           WHEN container ILIKE '%module-if-you-liked%' THEN 'module-if-you-liked'
           WHEN container ILIKE '%bbc-three%' THEN 'module-bbc-three'
           ELSE container END as container,
       id_type,
       count(*)               as clicks
FROM dataforce_sandbox.vb_homepage_clicks
WHERE age_range in ('16-24', '25-34')
GROUP BY 1, 2, 3;

-- this gives the success of the module
SELECT distinct age_range,
                CASE
                    WHEN click_container ILIKE '%module-if-you-liked%' THEN 'module-if-you-liked'
                    WHEN click_container ILIKE '%bbc-three%' THEN 'module-bbc-three'
                    ELSE click_container END as click_container,
                count(*)                     as clicks,
                sum(start_flag)              as starts,
                sum(complete_flag)           as completes
FROM central_insights_sandbox.vb_journey_start_watch_complete a
WHERE dt BETWEEN (SELECT min_date FROM dataforce_sandbox.vb_temp_date) AND (SELECT max_date FROM dataforce_sandbox.vb_temp_date)
  AND app_type = 'bigscreen-html'
  AND click_placement = 'home_page'
AND age_range in ('16-24', '25-34')
GROUP BY 1,2
ORDER BY 2 DESC;

SELECT distinct age_range FROM central_insights_sandbox.vb_journey_start_watch_complete LIMIT 10;

-- What impressions are there?
with impr_data AS (
    SELECT age_range,
           CASE
               WHEN container ILIKE '%module-if-you-liked%' THEN 'module-if-you-liked'
               WHEN container ILIKE '%bbc-three%' THEN 'module-bbc-three'
               ELSE container END as container,
           content_id,
           CASE
               WHEN content_id IN (SELECT distinct version_id from dataforce_sandbox.vb_vmb) THEN 'version_id'
               WHEN content_id IN (SELECT distinct episode_id from dataforce_sandbox.vb_vmb) THEN 'episode_id'
               WHEN content_id IN (SELECT distinct series_id from dataforce_sandbox.vb_vmb) THEN 'series_id'
               WHEN content_id IN (SELECT distinct brand_id from dataforce_sandbox.vb_vmb) THEN 'brand_id'
               ELSE 'unknown' END as id_type
    FROM central_insights_sandbox.vb_journey_homepage_impressions
    WHERE dt BETWEEN (SELECT min_date FROM dataforce_sandbox.vb_temp_date) AND (SELECT max_date FROM dataforce_sandbox.vb_temp_date)
      AND placement = 'iplayer.tv.page'

)
SELECT age_range, container, id_type, count(*)
FROM impr_data
WHERE age_range in ('16-24', '25-34')
GROUP BY 1, 2,3
ORDER BY 4 DESC;
