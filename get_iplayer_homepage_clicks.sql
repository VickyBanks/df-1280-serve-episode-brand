/*
 Get all the clicks to the homepage for a given week

 */
CREATE TEMP TABLE vb_temp_date
(
    min_date varchar(20),
    max_date varchar(20)
);
insert into vb_temp_date
values (20210315, 20210321);
SELECt * FROM vb_temp_date;

 ------------ 2. To make life easier with using the publisher table add in unique_visitor_cookie_id into user's table ------------
-- get user info
DROP TABLE vb_journey_test_users_uv;
CREATE TEMP TABLE vb_journey_test_users_uv AS
with inlineTemp AS (
    SELECT DISTINCT destination,
                    dt,
                    visit_id,
                    hashed_id,
                    app_type
    FROM s3_audience.audience_activity
    WHERE destination = 'PS_IPLAYER'
      AND dt BETWEEN (SELECT min_date FROM vb_temp_date) AND (SELECT max_date FROM vb_temp_date)
      AND is_signed_in = true
      AND geo_country_site_visited = 'United Kingdom'
      AND destination = 'PS_IPLAYER'
      and app_type = 'bigscreen-html'
      AND NOT (page_name = 'keepalive'
        OR page_name ILIKE '%mvt.activated%'
        OR page_name ILIKE 'iplayer.load.page'
        )
),
     visits AS (SELECT DISTINCT unique_visitor_cookie_id,
                                visit_id,
                                audience_id,
                                dt
                FROM s3_audience.visits
                WHERE destination = 'PS_IPLAYER'
                  AND dt BETWEEN (SELECT min_date FROM vb_temp_date) AND (SELECT max_date FROM vb_temp_date)
     )
SELECT DISTINCT a.destination,
                a.dt,
                a.visit_id,
                a.hashed_id,
                a.app_type,
                b.unique_visitor_cookie_id

FROM inlineTemp a
         JOIN visits b ON (a.hashed_id = b.audience_id AND a.visit_id = b.visit_id AND a.dt = b.dt)
;
--Check table
SELECT * FROM vb_journey_test_users_uv LIMIT 10;
SELECT app_type, dt, count(distinct dt||visit_id) as visits
FROM vb_journey_test_users_uv
GROUP BY 1,2
ORDER BY 1,2;

-- Get clicks on homepage
CREATE TABLE dataforce_sandbox.vb_content_clicks AS
SELECT DISTINCT a.dt,
                a.unique_visitor_cookie_id,
                b.hashed_id,
                a.visit_id,
                a.event_position,
                a.container,
                a.attribute,
                a.placement,
                a.result,
                a.user_experience,
                a.event_start_datetime
FROM s3_audience.publisher a
         JOIN vb_journey_test_users_uv b -- this is to bring in only those visits in our journey table
              ON a.dt = b.dt AND a.unique_visitor_cookie_id = b.unique_visitor_cookie_id AND
                 b.visit_id = a.visit_id
WHERE (a.attribute LIKE 'content-item%' OR a.attribute LIKE 'start-watching%' OR a.attribute = 'resume' OR
       a.attribute = 'next-episode' OR a.attribute = 'search-result-episode~click' OR a.attribute = 'page-section-related~select')
  AND a.container != 'resume-restart-gate' -- the resume restart gate falsly looks like a click because it carries the label "resume"
  AND a.publisher_clicks = 1
  AND a.destination = b.destination
  AND a.dt BETWEEN (SELECT min_date FROM vb_temp_date) AND (SELECT max_date FROM vb_temp_date)
AND a.placement = 'iplayer.tv.page'
;

SELECt * FROM dataforce_sandbox.vb_content_clicks LIMIT 10;

-- Get just homepage clicks on tv
DROP TABLE dataforce_sandbox.vb_homepage_clicks;
CREATE TABLE dataforce_sandbox.vb_homepage_clicks AS
SELECT a.app_type,
       a.dt,
       a.visit_id,
       b.placement,
       b.container,
       b.attribute,
       b.result               as content_id,
       CASE
           WHEN result IN (SELECT distinct episode_id from vb_vmb) THEN 'ep_id'
           WHEN result IN (SELECT distinct series_id from vb_vmb) THEN 'series_id'
           WHEN result IN (SELECT distinct brand_id from vb_vmb) THEN 'brand_id'
           ELSE 'unknown' END as id_type
FROM vb_journey_test_users_uv a
         LEFT JOIN dataforce_sandbox.vb_content_clicks b ON a.visit_id = b.visit_id AND a.dt = b.dt and
                                                            a.unique_visitor_cookie_id = b.unique_visitor_cookie_id
;

SELECT * FROM dataforce_sandbox.vb_homepage_clicks LIMIT 10;
SELECT app_type, dt, count(distinct dt||visit_id) as visits
FROM dataforce_sandbox.vb_homepage_clicks
GROUP BY 1,2
ORDER BY 1,2;