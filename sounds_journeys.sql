/*
 Initial investigation into journeys on Sounds

 1. What platforms send play start/extend/complete labels?
 2. What labels are there for clicks to content?
 3. Are there any issues with things like autoplay?
 4. Need only UK people? Or need to be able to identify where they're from
 */

 -- 1. What platforms send play start/extend/complete labels?
SELECT distinct metadata, attribute
FROM s3_audience.publisher
WHERE attribute in ('episode~start','episode~extended-play','episode~complete')
AND dt = 20210322;